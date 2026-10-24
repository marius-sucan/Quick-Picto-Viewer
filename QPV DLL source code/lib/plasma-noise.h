// plasma-noise.h
//
// PlasmaNoise: CImg's draw_plasma() reproduced exactly, written straight into a bitmap's bits,
// optionally blurred first. Used by generatePlasmaNoiseBitmap().
//
// The canvas is the image rounded up to 2^scale, wrapped around, with the image centred in it.
// Every draw has a fixed place in the generator's sequence, reached with a jump-ahead table, so
// a point depends only on its coordinates and the canvas is computed in tiles, in parallel.
//
// written by Marius Șucan with Claude Opus 5.5

#ifndef QPV_PLASMA_NOISE_H
#define QPV_PLASMA_NOISE_H

#include <cstdint>
#include <mutex>
#include <vector>

class PlasmaNoise {
public:
    // each plasma continues the generator's sequence from the previous one
    PlasmaNoise(const int w, const int h, const int intensity, const int details, const int scale) : width(w), height(h) {
        const float fs = (float)scale/9.5f;
        delta = 1 << ((fs>=12.0f) ? 12 : (fs>0.0f) ? (int)fs : 0);
        W = (int)(((INT64)w + delta - 1) / delta * delta);
        H = (int)(((INT64)h + delta - 1) / delta * delta);
        offX = (W - w)/2;
        offY = (H - h)/2;
        alpha = (float)intensity/2.0f;
        beta = (float)details/2.0f;

        uint64_t n = (uint64_t)(W/delta) * (H/delta);
        int level = 0;
        for (int s = delta; s>1; s >>= 1)
        {
            levelBase[level++] = n;
            n += 3ULL * (W/s) * (H/s);
        }
        perChannel = n;

        jumpA[0] = lcgA;
        jumpC[0] = lcgC;
        for (int k = 1; k < 64; k++)
        {
            jumpA[k] = jumpA[k - 1]*jumpA[k - 1];
            jumpC[k] = jumpC[k - 1]*(jumpA[k - 1] + 1);
        }

        std::lock_guard<std::mutex> lock(rngMutex);
        s1 = rngState*lcgA + lcgC;
        rngState = jump(s1, 4*perChannel);
    }

    // every channel is a plasma of its own, cut to [0, 255]; nc is 3 or 4 bytes per pixel. A blur above 0 is the
    // deviation of a Gaussian the plasmas are blurred by before the cut. Throws on allocation and OpenCV failures.
    void render(BYTE *scan0, const INT64 stride, const int nc, const int blurX, const int blurY) const {
        const Blur bx = Blur::ofSigma(blurX), by = Blur::ofSigma(blurY);
        std::vector<float> scratch((size_t)omp_get_max_threads()*2*gridSize);  // two grids for each thread
        if (bx.ksize>1 || by.ksize>1)
           renderBlurred(scan0, stride, nc, bx, by, scratch.data());
        else
           renderTiles(scan0, stride, nc, scratch.data());
    }

private:
    // a 64-bit LCG drawing its low 32 bits
    static constexpr uint64_t lcgA = 1103515245ULL, lcgC = 12345ULL;
    static inline std::mutex rngMutex;
    static inline uint64_t rngState = 0xB16B00B5ULL;

    static constexpr int tileSize = 256;
    static constexpr size_t gridSize = (size_t)(tileSize + 8) * (tileSize + 8);
    static constexpr int channelOffsets[4] = {2, 1, 0, 3};  // 4 channels are R, G, B and A; 24 bits pixels take the first 3

    int width, height;  // the image
    int W, H, delta, offX, offY;  // the canvas
    float alpha, beta;
    uint64_t s1, perChannel;
    uint64_t levelBase[12];  // a channel's first draw at each level
    uint64_t jumpA[64], jumpC[64];  // the generator advanced by 2^k draws

    struct Blur {
        int ksize;
        double sigma;
        bool stack;

        // a Gaussian of deviation sigma; past 4, a stack blur of the same variance, r*(r + 2)/6 for radius r
        static Blur ofSigma(const int sigma) {
            if (sigma<1)
               return {1, 0.0, false};
            if (sigma<=4)
               return {6*sigma + 1, (double)sigma, false};

            const int r = (int)(sqrt(6.0*sigma*sigma + 1.0) - 0.5);
            return {2*r + 1, (double)sigma, true};
        }

        void apply(cv::Mat &m, const bool vertical) const {
            if (ksize<2)
               return;

            const cv::Size k = vertical ? cv::Size(1, ksize) : cv::Size(ksize, 1);
            if (stack)
               cv::stackBlur(m, m, k);
            else
               cv::GaussianBlur(m, m, k, sigma, sigma, cv::BORDER_REPLICATE);
        }
    };

    // draw k in [-1, 1]
    struct Draws {
        const PlasmaNoise &p;
        uint64_t state, last;
        double operator()(const uint64_t k) {
            if (k==last + 1)
               state = state*lcgA + lcgC;
            else
               state = (k>last) ? p.jump(state, k - last) : p.jump(p.s1, k + 1);
            last = k;
            return -1.0 + 2.0*(uint32_t)state/4294967295.0;
        }
    };

    static inline int floorDiv(const int a, const int b) {
        return (a>=0) ? a / b : -((b - 1 - a) / b);
    }

    static inline int wrap(const int a, const int m) {
        if ((unsigned)a<(unsigned)m)
           return a;

        const int r = a % m;
        return (r<0) ? r + m : r;
    }

    static inline BYTE toByte(const float v) {
        return (BYTE)(((v<0.0f) ? 0.0f : (v>255.0f) ? 255.0f : v) + 0.4999f);
    }

    uint64_t jump(uint64_t s, uint64_t n) const {
        for (int k = 0; n; n >>= 1, k++)
            if (n & 1)
               s = jumpA[k]*s + jumpC[k];
        return s;
    }

    // channel c over the canvas rectangle [x0, x0 + tw) x [y0, y0 + th); returns the value at (x0, y0), rows gs apart.
    // The grid of spacing s holds the points (kx*s, ky*s) for kx in [x0/s - 3, (x0 + tw - 1)/s + 3]. The next grid
    // reads it 2 points in from its edges, and its outer ring has no diamond points.
    const float* tile(const int c, const int x0, const int y0, const int tw, const int th, float *g, float *n, int &gs) const {
        Draws draw = {*this, s1, UINT64_MAX};
        const uint64_t base = (uint64_t)c * perChannel;
        int s = delta;
        int kx0 = floorDiv(x0, s) - 3, ky0 = floorDiv(y0, s) - 3;
        int nx = floorDiv(x0 + tw - 1, s) + 4 - kx0;
        const int ny = floorDiv(y0 + th - 1, s) + 4 - ky0;
        float r = alpha*s + beta;
        for (int j = 0; j < ny; j++)
        {
            const uint64_t row = base + (uint64_t)wrap(ky0 + j, H/s) * (W/s);
            for (int i = 0; i < nx; i++)
                g[j*nx + i] = (float)(r*draw(row + wrap(kx0 + i, W/s)));
        }

        for (int level = 0; s>1; s >>= 1, level++)
        {
            const int h = s>>1, cols = W/s, wx = W/h, wy = H/h;
            const int mx0 = floorDiv(x0, h) - 3, my0 = floorDiv(y0, h) - 3;
            const int mx = floorDiv(x0 + tw - 1, h) + 4 - mx0, my = floorDiv(y0 + th - 1, h) + 4 - my0;
            const uint64_t squares = base + levelBase[level], diamonds = squares + (uint64_t)(H/s) * cols;
            r = alpha*s + beta;

            // the coarser grid's points and the squares' centres
            for (int j = 0; j < my; j++)
            {
                const int ky = my0 + j;
                const float *o = g + ((ky>>1) - ky0)*nx;
                float *m = n + j*mx;
                if ((ky & 1)==0)
                {
                    for (int i = mx0 & 1; i < mx; i += 2)
                        m[i] = o[((mx0 + i)>>1) - kx0];
                } else
                {
                    const uint64_t row = squares + (uint64_t)(wrap(ky, wy)>>1) * cols;
                    for (int i = 1 - (mx0 & 1); i < mx; i += 2)
                    {
                        const int a = ((mx0 + i)>>1) - kx0;
                        m[i] = (float)(0.25f*(o[a] + o[a + 1] + o[nx + a + 1] + o[nx + a]) + r*draw(row + (wrap(mx0 + i, wx)>>1)));
                    }
                }
            }

            // the diamonds' centres
            for (int j = 1; j < my - 1; j++)
            {
                const int ky = my0 + j;
                float *m = n + j*mx;
                const uint64_t row = diamonds + (uint64_t)wrap(ky, wy) * cols;
                for (int i = 2 - ((mx0 + 1 + ky) & 1); i < mx - 1; i += 2)
                    m[i] = (float)(0.25f*(m[i - 1] + m[i + 1] + m[i - mx] + m[i + mx]) + r*draw(row + (wrap(mx0 + i, wx)>>1)));
            }

            std::swap(g, n);
            kx0 = mx0;
            ky0 = my0;
            nx = mx;
        }

        gs = nx;
        return g + 3*nx + 3;
    }

    void renderTiles(BYTE *scan0, const INT64 stride, const int nc, float *scratch) const {
        const int T = tileSize, tilesX = (width + T - 1)/T, tiles = tilesX * ((height + T - 1)/T);
        #pragma omp parallel for schedule(dynamic)
        for (int t = 0; t < tiles; t++)
        {
            float *g = scratch + (size_t)omp_get_thread_num()*2*gridSize;
            const int tx = (t % tilesX)*T, ty = (t / tilesX)*T;
            const int tw = min(T, width - tx), th = min(T, height - ty);
            for (int c = 0; c < nc; c++)
            {
                int gs;
                const float *v = tile(c, offX + tx, offY + ty, tw, th, g, g + gridSize, gs);
                for (int j = 0; j < th; j++)
                {
                    const float *row = v + (INT64)j*gs;
                    BYTE *px = scan0 + (ty + j)*stride + (INT64)tx*nc + channelOffsets[c];
                    for (int i = 0; i < tw; i++, px += nc)
                        *px = toByte(row[i]);
                }
            }
        }
    }

    // channel c over the image rectangle [x, x + w) x [y, y + h), rows dstStride floats apart
    void channelToFloats(const int c, const int x, const int y, const int w, const int h, float *dst, const INT64 dstStride, float *scratch) const {
        const int T = tileSize, tilesX = (w + T - 1)/T, tiles = tilesX * ((h + T - 1)/T);
        #pragma omp parallel for schedule(dynamic)
        for (int t = 0; t < tiles; t++)
        {
            float *g = scratch + (size_t)omp_get_thread_num()*2*gridSize;
            const int tx = (t % tilesX)*T, ty = (t / tilesX)*T;
            const int tw = min(T, w - tx), th = min(T, h - ty);
            int gs;
            const float *v = tile(c, offX + x + tx, offY + y + ty, tw, th, g, g + gridSize, gs);
            for (int j = 0; j < th; j++)
                memcpy(dst + (ty + j)*dstStride + tx, v + (INT64)j*gs, tw*sizeof(float));
        }
    }

    // the values are blurred before they are cut to bytes; a channel goes in bands across the axis blurred less,
    // each band computed with a margin as wide as that blur reaches
    void renderBlurred(BYTE *scan0, const INT64 stride, const int nc, const Blur &bx, const Blur &by, float *scratch) const {
        const int w = width, h = height;
        const int rx = bx.ksize/2, ry = by.ksize/2;
        // OpenCV's stack blur gets the last radius pixels of a row wrong, so rows go on that far, repeating their last pixel
        const int pad = bx.stack ? rx : 0;
        const bool rowBands = (ry<rx);
        const int len = rowBands ? h : w, reach = rowBands ? ry : rx;
        const int band = max(256, 2*reach), span = min(len, band + 2*reach);
        std::vector<float> plane((size_t)((rowBands ? w : span) + pad) * (rowBands ? span : h));

        for (int c = 0; c < nc; c++)
        {
            for (int b0 = 0; b0 < len; b0 += band)
            {
                const int b1 = min(len, b0 + band), e0 = max(0, b0 - reach), e1 = min(len, b1 + reach);
                const int ew = rowBands ? w : e1 - e0, eh = rowBands ? e1 - e0 : h, pw = ew + pad;
                channelToFloats(c, rowBands ? 0 : e0, rowBands ? e0 : 0, ew, eh, plane.data(), pw, scratch);
                if (pad>0)
                {
                    #pragma omp parallel for schedule(static)
                    for (int j = 0; j < eh; j++)
                    {
                        float *row = plane.data() + (INT64)j*pw;
                        std::fill(row + ew, row + pw, row[ew - 1]);
                    }
                }

                cv::Mat m(eh, pw, CV_32F, plane.data());
                bx.apply(m, false);
                by.apply(m, true);

                // the band without its margins
                const int bw = rowBands ? w : b1 - b0, bh = rowBands ? b1 - b0 : h;
                const int px0 = rowBands ? 0 : b0, py0 = rowBands ? b0 : 0;
                const float *src = plane.data() + (INT64)(py0 - (rowBands ? e0 : 0))*pw + (px0 - (rowBands ? 0 : e0));
                #pragma omp parallel for schedule(static)
                for (int j = 0; j < bh; j++)
                {
                    const float *row = src + (INT64)j*pw;
                    BYTE *px = scan0 + (py0 + j)*stride + (INT64)px0*nc + channelOffsets[c];
                    for (int i = 0; i < bw; i++, px += nc)
                        *px = toByte(row[i]);
                }
            }
        }
    }
};

#endif // QPV_PLASMA_NOISE_H

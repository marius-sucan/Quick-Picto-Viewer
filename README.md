<h1>Quick Picto Viewer</h1>

<h2>To keep the development going, <a href="https://www.paypal.me/MariusSucan/10">please donate</a> using PayPal.</h2>

<p>This is an image viewer and [basic] editor based on the GDI+ and FreeImage libraries. It can open about 85 image file formats: .hdr, .raw, .tif, .emf, .wmf, .png, .bmp, .gif, .jpeg and many others.</p>

<p>QPV is able to create image slideshows and cache very large dynamic lists of files. Unlike other applications of this kind, it can load, on my system, a list of 500000 files in under 10 seconds, while XnView Classic or Irfan View need more than 15 minutes. The index of files can be saved as plain-text or as an SQLite database.</p>

<p>With Quick Picto Viewer you can generate file statistics over huge image libraries which can help identify very small images, very low key, or washed out images. You can also identify image duplicates and auto-select files by given criteria.</p>

<p>Quick Picto Viewer is also able to play sound files associated with images, automatically or on demand, and even generate slideshows that are in synch with the audio files duration. Supported audio formats: WAV, MP3 and WMA. It can also display image captions / notes for image.</p>

<p>Since Quick Picto Viewer v4, users can also edit images by using freely rotated elliptical or rectangular selections. Common functions provided: paste in place, color adjustments, draw arcs, lines or shapes, insert text, soft edges blur area and so on.</p>

<p width="600" height="410"><img width="600" height="410" alt="Quick Picture Viewer - thumbnails list screenshot" src="http://marius.sucan.ro/media/files/blog/ahk-scripts/images/quick-picto-viewer-screenshot.jpg"></p>

<p width="600" height="410"><img width="600" height="410" alt="Quick Picture Viewer - image view screenshot" src="http://marius.sucan.ro/media/files/blog/ahk-scripts/images/quick-picto-viewer-screenshot2.jpg"></p>


<h2><a href="http://marius.sucan.ro/media/files/blog/ahk-scripts/quick-picto-viewer-compiled.zip">Download latest version</a> (compiled for x64/x32, Windows binary)</h2>

<p>QPV runs on Windows XP*, Windows 7 and Windows 10.</p>

<p>Source code available on <a href="https://github.com/marius-sucan/Quick-Picto-Viewer">Github</a>.</p>

<p><em>To run the uncompiled edition, download the ZIP file.</em> Required DLL files are included in the ZIP file, except for those needed to run on Windows XP.</p>

<h1>Features</h1>

<ul>
<li>Support for 85 image file formats, including various Camera RAW formats.</li>
<li>List images as thumbnails with preset aspect ratios: square, wide or tall. Easy to adjust their size as well. Use T and +/- keys.</li>
<li>Adaptive multi-threaded thumbnails caching to sizes ranging from 600 pixels to 125 pixels. On very fast PCs, no caching occurs.</li>
<li>Touch screen friendly hot-areas on the UI to navigate or zoom into images.</li>
<li>Sort images by histogram average or median point, resolution, aspect ratio, or by similarity.</li>
<li>Options to control brightness, contrast, saturation and RGB color channels balance/intensity.</li>
<li>Elliptical and rectangular selections, rotated at any angle.</li>
<li>Image editing: soft edges blur, insert text, paste in place, draw arcs, lines and shapes, transform selected area, rotate, flip, crop and more</li>
<li>Draw free-form curved paths or polygonal lines; options to use fill with color or gradients, or use as alpha masks.</li>
<li>18 blending modes and alpha masking support on paste in place or when using the transform tool on a selected area. The mask can be a gradient [linear, box, radial], an image file or a previously drawn path.</li>
<li>Adaptive auto-adjustment of brightness, contrast and saturation of displayed images.</li>
<li>Advanced yet easy to use auto-crop for images.</li>
<li>Display images in grayscale, inverted or personalized colors. Option to save adjusted image, or apply adjusments on multiple images in one go.</li>
<li>Real-time histogram for any image color channel of the image displayed.</li>
<li>Various modes to adapt images to window.</li>
<li>Images can be rotated or mirrored horizontally and vertically in the viewport.</li>
<li>Multiple list view modes. Display the indexed files as an easy to scroll list with or without details.</li>
<li>Multiple slideshow directions available and easy to change speed between images: random order, backwards or forwads.</li>
<li>Option to keep a record of seen images and have these skipped during slideshows or erased from the index list</li>
<li>Add/remove or manage favourite images</li>
<li>Perform JPEG lossless operations in batch: flip or crop images.</li>
<li>Perform actions on image files: resize, rotate [at any degree], crop, change/adjust colors, rename, convert to different file formats, rename, delete, copy or move.</li>
<li>Batch processing. You can apply any of the previously mentioned action or operation on multiple files at once.</li>
<li>Multi-rename allows adding a prefix and/or suffix to renamed files, or to count them, or search and replace strings in file names.</li>
<li>Acquire images from scanners.</li>
<li>File statistics panel with categories for: file sizes, file types, modified dates, image size, image histogram data and much more.</li>
<li>Identify image duplicates by customizable image properties, histogram details or image content similarity.</li>
<li>Copy files from Explorer and paste in Quick Picto Viewer, or from QPV to Explorer.</li>
<li>Paste texts from clipboard and render them as images. Text and background colors, font style, alignment and size can be personalized.</li>
<li>Quick Picto Viewer has its own slideshow formats to store list of folders and cache files lists: plain-text and SQLite database.</li>
<li>Ability to selectively refresh the cached files list from selected folders.</li>
<li>Option to filter the list of files using keywords. The operator | [or] is allowed.</li>
<li>Very fast loading of cached or not cached lists of files. Tested with 700000 images and it loads in 10 seconds on my system.</li>
<li>Resize and crop images preserving alpha-channel on save even when image colors are adjusted.</li>
<li>Support for animated .GIFs in slideshows.. HD GIFs support as well.</li>
<li>Support for multi-paged TIFFs and GIF frames. Ability to go through each image frame/page.</li>
<li>Support for drag 'n drop of folders or files onto main UI.</li>
<li>Paste image from clipboard and save it. 17 file formats supported for saving an image.</li>
<li>Copy to clipboard: the entire image or an area selected from it.</li>
<li>Adjustable user interface font sizes and colors.</li>
<li>Ambiental textured window background. Automatically generated background based on the current image displayed.</li>
<li>Multi-monitor support.</li>
<li>Fancy welcome screen random-generated images :-).</li>
<li>All the potentially lengthy operations can be stopped with Escape or by a single click on the main window :-).</li>
</ul> 

<p>Developed by <a href="http://marius.sucan.ro/">Marius Șucan</a> with special attention for people with disabilities.</p>

<p>I coded the application as an <a href="https://autohotkey.com/">AHK script</a> for AutoHotkey_H v1.1.32. To execute or compile the source code one needs AHK_H. <em>The required DLL files are found in the provided ZIP compiled script package</em>.</p>

<p>(*) Quick Picto Viewer can run on Windows XP, but various features might not work well. However, if you choose to do so, you must provide it with files found in Windows 10 (and possibly other Windows versions) installations. You must choose the ones that suit your Windows XP installation: DLLs for x32 or x64. These must be placed in the same folder with the QPV .EXE binary. The DLL files required are:</p>
<ul>
<li>api-ms-win-core-*-l1-1-0.dll [43 files]</li>
<li>api-ms-win-crt-*-l1-1-0.dll [15 files]</li>
<li>api-ms-win-core-file-l1-2-0.dll</li>
<li>api-ms-win-core-file-l2-1-0.dll</li>
<li>api-ms-win-core-localization-l1-2-0.dll</li>
<li>api-ms-win-core-synch-l1-2-0.dll</li>
<li>ucrtbase.dll</li>
</ul>

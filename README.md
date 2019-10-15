<h1>Quick Picto Viewer</h1>

<h2>To keep the development going, <a href="https://www.paypal.me/MariusSucan/10">please donate</a> using PayPal.</h2>

<p>This is an image viewer based on the GDI+ and FreeImage libraries. It can open 85 image file formats: .hdr, .raw, .tif, .emf, .wmf, .png, .bmp, .gif, .jpeg and many others.</p>

<p>QPV is able to create image slideshows and cache very large dynamic lists of files. Unlike other applications of this kind, it can load, on my system, a list of 500000 files in under 10 seconds, while XnView Classic or Irfan View need more than 15 minutes.</p>

<p width="600" height="540"><img width="600" height="540" alt="Quick Picture Viewer - thumbnails list screenshot" src="http://marius.sucan.ro/media/files/blog/ahk-scripts/quick-picto-viewer-screenshot.jpg"></p>

<p width="600" height="540"><img width="600" height="540" alt="Quick Picture Viewer - image view screenshot" src="http://marius.sucan.ro/media/files/blog/ahk-scripts/quick-picto-viewer-screenshot2.jpg"></p>

<h2><a href="http://marius.sucan.ro/media/files/blog/ahk-scripts/quick-picto-viewer-compiled.zip">Download latest version</a> (compiled for x64/x32, Windows binary)</h2>

<p>Source code available on <a href="https://github.com/marius-sucan/Quick-Picto-Viewer">Github</a>.</p>

<h1>Features</h1>

<ul>
<li>Support for 85 image file formats, including various Camera RAW formats.</li>
<li>List images as thumbnails with preset aspect ratios: square, wide or tall. Easy to adjust their size as well. Use T and +/- keys.</li>
<li>Adaptive thumbnails caching to sizes ranging from 600 pixels to 125 pixels. On fast PCs, no caching occurs.</li>
<li>Touch screen friendly hot-areas on the UI to navigate or zoom into images.</li>
<li>Options to control brightness, contrast, saturation and RGB color channels balance/intensity.</li>
<li>Adaptive auto-adjustment of brightness, contrast and saturation of displayied images.</li>
<li>Display images in grayscale, inverted or personalized colors. Option to save adjusted image, or apply adjusments on multiple images in one go.</li>
<li>Real-time luminance histogram for the image displayied.</li>
<li>Various modes to adapt images to window.</li>
<li>Images can be rotated or mirrored horizontally and vertically in the viewport.</li>
<li>Multiple slideshow directions available and easy to change speed between images: random order, backwards or forwads.</li>
<li>Perform JPEG lossless operations in batch: flip or crop images.</li>
<li>Perform actions on image files: resize, rotate [at any degree], crop, change/adjust colors, rename, convert to different file formats, rename, delete, copy or move.</li>
<li>Batch processing. You can apply any of the previously mentioned action or operation on multiple files at once.</li>
<li>Multi-rename allows adding a prefix and/or suffix to renamed files, or to count them, or search and replace strings in file names.</li>
<li>Paste texts from clipboard and render them as images. Text and background colors, font style, alignment and size can be personalized.</li>
<li>Quick Picto Viewer has its own slideshow format to store list of folders and cache files lists.</li>
<li>Ability to selectively refresh the cached files list from selected folders.</li>
<li>Option to filter the list of files using keywords. The operator | [or] is allowed.</li>
<li>Very fast loading of cached or not cached lists of files. Tested with 700000 images and it loads in 10 seconds on my system.</li>
<li>Resize and crop images preserving alpha-channel on save even when image colors are adjusted.</li>
<li>Support for animated .GIFs in slideshows.</li>
<li>Support for multi-paged TIFFs and GIF frames. Ability to go through each image frame/page.</li>
<li>Support for drag 'n drop of folders or files onto main UI.</li>
<li>Paste image from clipboard and save it. 18 file formats supported for saving an image.</li>
<li>Copy to clipboard: the entire image or an area selected from it.</li>
<li>Ambiental textured window background. Automatically generated background based on the current image displayied.</li>
<li>Fancy welcome screen random-generated images :-).</li>
<li>All the potentially lengthy operations can be stopped with Escape :-).</li>
</ul> 

<p>Developed by <a href="http://marius.sucan.ro/">Marius Șucan</a>.</p>

<p>I coded the application as an <a href="https://autohotkey.com/">AHK script</a> for AutoHotkey_L v1.1.30. To execute/compile the source code one needs AHK_L.</p>

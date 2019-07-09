<h1>Quick Picto Viewer</h1>

<h2>To keep the development going, <a href="https://www.paypal.me/MariusSucan/10">please donate</a> using PayPal.</h2>

<p>This is an image viewer based on GDI+. It can open: .dib, .tif, .tiff, .emf, .wmf, .rle, .png, .bmp, .gif, .jpeg files.</p>

<p>QPV is also able to create image slideshows and cache very large dynamic lists of files. Unlike other applications of this kind, it can load, on my system, a list of 500000 files on my system in under 10 seconds, while XnView Classic or Irfan View need more than 15 minutes.</p>

<p width="600" height="540"><img width="600" height="540" alt="Quick Picture Viewer - screenshot" src="http://marius.sucan.ro/media/files/blog/ahk-scripts/quick-picto-viewer-screenshot.jpg"></p>

<h2><a href="http://marius.sucan.ro/media/files/blog/ahk-scripts/quick-picto-viewer-compiled.zip">Download latest version</a> (compiled for x64/x32, Windows binary)</h2>

<p>Source code available on <a href="https://github.com/marius-sucan/Quick-Picto-Viewer">Github</a>.</p>

<h1>Features</h1>

<ul>
<li>Support for common image file formats.</li>
<li>List images as thumbnails with preset aspect ratios: square, wide or tall. Easy to adjust their size as well.</li>
<li>Adaptive thumbnails caching to sizes ranging from 600 pixels to 125 pixels. On fast PCs, no caching occurs.</li>
<li>Touch screen friendly hot-areas on the UI to navigate or zoom into images.</li>
<li>Display images in grayscale, inverted or personalized colors. Easy to adjust gamma and brightness. Option to save adjusted image, or apply adjusments on multiple images in one go.</li>
<li>Various modes to adapt images to window.</li>
<li>Multiple slideshow directions available and easy to change speed between images: random order, backwards or forwads.</li>
<li>Perform actions on image files: resize, change/adjust colors, rename, convert to jpeg, delete, copy or move.</li>
<li>Operations in batch [on multiple files at once]: resize images, change/adjust colors, convert to jpeg, delete, copy, move, and rename.</li>
<li>Multi-rename allows adding a prefix and/or suffix to renamed files, or to count them, or search and replace strings in file names.</li>
<li>Quick Picto Viewer has its own slideshow format to store list of folders and cache files lists.</li>
<li>Ability to selectively refresh the cached files list from selected folders.</li>
<li>Option to filter the list of files using keywords. The operator | [or] is allowed.</li>
<li>Very fast loading of cached or not cached lists of files. Tested with 700000 images, load times under 10 seconds.</li>
<li>Support for animated .GIFs in slideshows.</li>
<li>Support for drag 'n drop of folders or files onto main UI.</li>
<li>Paste image from clipboard and save it as PNG, JPG or BMP.</li>
<li>Copy image to clipboard.</li>
<li>All the potentially lengthy operations can be stopped with Escape :-).</li>
</ul> 

<p>Developed by <a href="http://marius.sucan.ro/">Marius Șucan</a>.</p>

<p>I coded the application as an <a href="https://autohotkey.com/">AHK script</a> for AutoHotkey_L v1.1.30. To execute/compile the source code one needs AHK_L.</p>

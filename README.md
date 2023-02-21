<h1>Quick Picto Viewer</h1>

<h2>To keep the development going, <a href="https://www.paypal.me/MariusSucan/10">please donate</a> using PayPal.</h2>

<p>QPV is an image viewer, editor and a tool to organize image collections based on the GDI+ and FreeImage libraries. It can open about 85 image file formats: .hdr, .raw, .tif, .emf, .wmf, .png, .bmp, .gif, .jpeg and many others.</p>

<h2><a href="https://marius.sucan.ro/media/files/blog/ahk-scripts/quick-picto-viewer-compiled.zip">Download latest version</a> (compiled for  Windows, as a x64 binary)</h2>

<p>QPV is able to create image slideshows and cache very large dynamic lists of files. Unlike other applications of this kind, it can load, on my system, a list of 900100 files in under 10 seconds, while XnView Classic or Irfan View need more than 15 minutes. The index of files can be saved as plain-text or as an SQLite database.</p>

<p>With Quick Picto Viewer you can generate file statistics over huge image libraries which can help identify very small images, very low key, or washed out images. You can also identify image duplicates and auto-select files by given criteria.</p>

<p>QPV also has specific tools to index image contents and identify image duplicates, based on similarity. Users can choose from four algorithms to identify the duplicates.</p>

<p>Quick Picto Viewer is also able to play sound files associated with images, automatically or on demand, and even generate slideshows that are in synch with the audio files duration. Supported audio formats: WAV, MP3 and WMA. It can also display image captions / notes for image.</p>

<p>QPV can be used to edit images and/or paint new images. Various tools to this end are available, including blending modes and alpha masking abilities. Please see the features list to learn more in details what QPV can do.</p>

<h2>In action</h2>

<p><a href="https://www.youtube.com/watch?v=Q-_tBX-a8ko">Video showing file management capabilities.</a></p>
<p><a href="https://www.youtube.com/watch?v=YneYL1TXXtg">Image painting time-lapse. The video shows the image editing capabilities.</a></p>
<p><a href="https://www.youtube.com/playlist?list=PLlfQlmy-i21bWEoFJKKH2dBZvt0yabRBV">YouTube playlist with more videos.</a></p>

<p width="600" height="410"><img width="600" height="410" alt="Quick Picture Viewer - thumbnails list screenshot" src="https://marius.sucan.ro/media/files/blog/ahk-scripts/images/qpv-screenshot1.jpg"></p>

<p width="600" height="410"><img width="600" height="410" alt="Quick Picture Viewer - image view screenshot" src="https://marius.sucan.ro/media/files/blog/ahk-scripts/images/qpv-screenshot2.jpg"></p>

<p>QPV runs on Windows 7, Windows 10 and Windows 11, and with some efforts, even on Windows XP - please read the notes at the end.</p>

<p>Source code available on <a href="https://github.com/marius-sucan/Quick-Picto-Viewer">Github</a>.</p>

<p><em>If you want to run the uncompiled edition, please make sure you download the required DLL files from the Github repository, or the ones included in the ZIP file.</em></p>

<h1>Features</h1>

<h2>IMAGE EDITING:</h2>

<ul>
<li>Options to control viewport brightness, contrast, saturation and RGB color channels balance/intensity.</li>

<li>Adaptive auto-adjustment of brightness, contrast and saturation of displayed images.</li>

<li>Images can be rotated or mirrored horizontally and vertically in the viewport.</li>

<li>Paint brushes: soft edges, cloner, eraser, pinch, bulge, smudge and more:</li>
<ul>
   <li>ability to randomize various brush properties when painting</li>
   <li>textured brushes</li>
   <li>paint with symmetry</li>
</ul>

<li>Image editing tools: </li>
<ul>
   <li>draw arcs, lines and filled shapes</li>
   <li>parametric line generators [grids, spirals, rays and more]</li>
   <li>advanced flood fill [color bucket]</li>
   <li>insert text with advanced customization options</li>
   <li>paste in place</li>
   <li>transform selected area</li>
   <li>various blur filters: gaussian, box blur, radial blur and others</li>
   <li>rotate, crop, flip, pixelize, add noise, and more.</li>
</ul>

<li>Draw free-form Bézier curved paths or polygonal lines; options to fill with color, textures or gradients.</li>

<li>Free-form curved or polygonal selections, elliptical and rectangular selections, rotated at any angle.</li>

<li>Vector shapes can be defined with symmetry on X or Y axis.</li>

<li>Ability to save/load user created vector paths.</li>

<li>18 blending modes and alpha masking support implemented for various image editing tools.</li>

<li>Alpha mask can be user painted or generated: a gradient [linear, box, radial] or a previously drawn vector path.</li>

<li>Advanced yet easy to use auto-crop for images.</li>

<li>Real-time histogram for any image color channel of the image displayed.</li>

<li>Easy to configure viewport grid.</li>

<li>Paste texts from clipboard and render them as images. Text and background colors, font style, alignment and size can be personalized.</li>

<li>Copy / paste image to/ from clipboard with the alpha channel preserved.</li>

<li>Print image. Users can add text, adjust size and position on the page before printing.</li>

<li>Acquire images from scanners.</li>

<li>Resize and crop images preserving the alpha-channel on save.</li>

<li>Multiple file formats supported for saving an image.</li>
</ul>

<h2>FILES MANAGEMENT</h2>
<ul>
<li>Omnibox and folders tree view - two specialized panels meant to help users navigate through folders, with support for drag and drop amongst them.</li>

<li>Quick file actions. Easily move or copy files to user defined folder paths using the number keys: 1 to 6.</li>

<li>Ability to automatically group files into sub-folders based on file types or modification date, by months or years.</li>

<li>Tool to copy or move files by maintaining their folder(s) structure.</li>

<li>Create PDFs or multi-paged TIFFs from selected images. Up to 2048 images allowed.</li>

<li>Extract frames from GIF and WebP animated images, or pages from TIFFs.</li>

<li>Multiple list view modes. Display the indexed files as an easy to scroll list with or without image file details, or as thumbnails list.</li>

<li>The thumbnails list comes with three predefined aspect ratios: square, wide or tall. Easy to adjust their size: +/- keys.</li>

<li>Adaptive multi-threaded thumbnails caching to sizes ranging from 600 pixels to 125 pixels. On very fast PCs, no caching occurs.</li>

<li>Files can automatically be selected by strings, or the ones already seen, favourited, and other options.</li>

<li>Files list map. A quick view, at a glance, of the files list, highlighting selected files.</li>

<li>Sort images by histogram data points, such as the average or median point, resolution, aspect ratio.</li>
<ul>
   <li>by their image properties: resolution, aspect ratio, width, height and so on</li>
   <li>by file properties: size, name, date, et cetera </li>
</ul>

<li>Option to keep a record of seen images and have these skipped during slideshows or erased from the index list. QPV can also generate statistics and charts based on the image viewing habits.</li>

<li>Image and folders favourites lists; easy to manage. The list can be very big, up to 950100 images.</li>

<li>Multi-rename. Rename multiple files with easy to use patterns. Users can add a prefix and/or suffix to file names, or to count them, or search and replace strings in file names, and more.</li>

<li>File statistics panel with categories for: file sizes, file types, modified dates, image size, image histogram data points and much more.</li>

<li>Identify image duplicates by user chosen image properties, histogram data points or image content similarity. Multiple algorithms are available to choose from.</li>

<li>Index filters: based on text strings or file and image properties.</li>

<li>Dedicated panel to automatically identify keywords in file names and folder paths, and option to filter the list based on any identified keyword.</li>

<li>Copy files from Explorer and paste in Quick Picto Viewer, or from QPV to Explorer.</li>

<li>Copy file names or folder paths as text to clipboard.</li>

<li>Quick Picto Viewer has its own slideshow formats to store the list of folders and cache files lists: plain-text and SQLite database.</li>

<li>Ability to selectively refresh the cached files list from selected folders.</li>

<li>Search and replace in the index, enabling users to correct potentially broken files lists.</li>

<li>Very fast loading of cached or not cached lists of files. Tested with 900100 images and it loads in 10 seconds on my system.</li>

<li>Support for drag and drop of folders or files on the QPV window.</li>

<li>Perform JPEG lossless operations in batch: flip or crop images.</li>

<li>Perform actions on image files: resize, rotate [at any degree], crop, change/adjust colors, rename, convert to different file formats, rename, delete, copy or move.</li>

<li>Batch processing. You can apply any of the previously mentioned action or operation on multiple files at once.</li>
</ul>

<h2>GENERAL / USER INTERFACE</h2>
<ul>
<li>Support for 85 image file formats, including various Camera RAW formats.</li>

<li>Touch screen friendly user interface: swipe gestures and hot-areas to navigate or zoom into images.</li>

<li>Adjustable user interface font sizes and colors.</li>

<li>Customizable keyboard shortcuts and toolbar icons.</li>

<li>Dark mode for the user interface.</li>

<li>Ambiental textured window background. Automatically generated background based on the currently displayed image.</li>

<li>Various modes to adapt images to window.</li>

<li>Vertical or horizontal toolbar. Toolbar size adjustable.</li>

<li>Slideshows, easy to change speed while running: random order, backwards or forwards.</li>

<li>Ability to set the slideshow duration.</li>

<li>Slideshow random modes: with a bias for the first or second half of the files list, or no explicit bias.</li>

<li>Option to set background music for the entire slideshow.</li>

<li>Audio annotations or text captions for any image file.</li>

<li>Quick search box allows users to search through menus and other available options in QPV.</li>

<li>Support for animated .WEBP and .GIFs in slideshows - HD GIFs are support as well.</li>

<li>Support for multi-paged .WEBP, .TIFFs and .GIF frames. Ability to go through each image frame/page.</li>

<li>Screen readers compatible. All the messages displayed in the viewport can be read through screen readers as well.</li>

<li>Private mode. In this mode, images are blurred, and file names and paths are hidden.</li>

<li>Multi-monitor support.</li>

<li>Fancy welcome screen random-generated images :-).</li>

</ul> 

<H1>Other details</H1>
<p>Developed by <a href="http://marius.sucan.ro/">Marius Șucan</a> with special attention for people with disabilities.</p>

<p>I coded the application as an <a href="https://autohotkey.com/">AHK script</a> for AutoHotkey_H v1.1.32, [newer versions are not yet supported]. To execute or compile the source code one needs <a href="https://hotkeyit.github.io/v2/">AHK_H</a>.</p>

<p>Quick Picto Viewer can run on Windows 7 and even on XP, but various features might not work. To this end, you may have to copy all the DLL files found in the .\optional-DLL-files-x64\ folder to the same folder where the QPV binary is. If you are running it uncompiled, you must place them in the folder where the AutoHotkey binary resides. The required DLLs for x64 are bundled since version 5.7.5 in the ZIP package and can also be found in the Github repository.</p>


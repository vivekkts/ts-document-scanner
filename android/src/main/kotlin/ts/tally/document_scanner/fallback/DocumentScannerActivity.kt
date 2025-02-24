package ts.tally.document_scanner.fallback

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Matrix
import android.icu.text.IDNA.Info
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.EditText
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.addCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import androidx.core.text.htmlEncode
import androidx.core.view.get
import androidx.core.view.isVisible
import androidx.core.view.setPadding
import androidx.recyclerview.widget.LinearSnapHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.android.material.button.MaterialButton
import com.google.android.material.carousel.CarouselLayoutManager
import com.google.android.material.carousel.CarouselSnapHelper
import com.google.android.material.carousel.FullScreenCarouselStrategy
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import ts.tally.document_scanner.R
import ts.tally.document_scanner.databinding.ActivityImagePreviewBinding
import ts.tally.document_scanner.databinding.PreviewCarouselBinding
import ts.tally.document_scanner.databinding.ThumbnailCarouselBinding
import ts.tally.document_scanner.fallback.constants.DefaultSetting
import ts.tally.document_scanner.fallback.constants.DocumentScannerAction
import ts.tally.document_scanner.fallback.constants.DocumentScannerExtra
import ts.tally.document_scanner.fallback.extensions.deselectAllItems
import ts.tally.document_scanner.fallback.extensions.move
import ts.tally.document_scanner.fallback.extensions.saveToFile
import ts.tally.document_scanner.fallback.extensions.screenHeight
import ts.tally.document_scanner.fallback.extensions.screenWidth
import ts.tally.document_scanner.fallback.extensions.write
import ts.tally.document_scanner.fallback.models.Document
import ts.tally.document_scanner.fallback.models.Point
import ts.tally.document_scanner.fallback.models.Quad
import ts.tally.document_scanner.fallback.ui.ImageCropView
import ts.tally.document_scanner.fallback.utils.CameraUtil
import ts.tally.document_scanner.fallback.utils.DocumentProviderType
import ts.tally.document_scanner.fallback.utils.DocumentProviderUtil
import ts.tally.document_scanner.fallback.utils.DocumentUtil
import ts.tally.document_scanner.fallback.utils.FileUtil
import ts.tally.document_scanner.fallback.utils.ImageUtil
import java.io.File
import androidx.appcompat.app.AlertDialog


/**
 * This class contains the main document scanner code. It opens the camera, lets the user
 * take a photo of a document (homework paper, business card, etc.), detects document corners,
 * allows user to make adjustments to the detected corners, depending on options, and saves
 * the cropped document. It allows the user to do this for 1 or more documents.
 *
 * @constructor creates document scanner activity
 */
class DocumentScannerActivity : AppCompatActivity() {
    /**
     * @property maxNumDocuments maximum number of documents a user can scan at a time
     */
    private var maxNumDocuments = DefaultSetting.MAX_NUM_DOCUMENTS

    /**
     * @property importedFilePath path of the file to serve as starting file for document selector
     */
    private var importedFilePath : String? = null

    private lateinit var thumbnailSnapHelper: LinearSnapHelper

    /**
     * @property croppedImageQuality the 0 - 100 quality of the cropped image
     */
    private var croppedImageQuality = DefaultSetting.CROPPED_IMAGE_QUALITY

    /**
     * @property cropperOffsetWhenCornersNotFound if we can't find document corners, we set
     * corners to image size with a slight margin
     */
    private val cropperOffsetWhenCornersNotFound = 40.0

    /**
     * @property document This is the current document. Initially it's null. Once we capture
     * the photo, and find the corners we update document.
     */
    private var document: Document? = null

    private var documentAction: String = DocumentScannerAction.NONE

    /**
     * @property documents a list of documents (original photo file path, original photo
     * dimensions and 4 corner points)
     */
    private val documents = mutableListOf<Document>()

    private lateinit var binding : ActivityImagePreviewBinding

    private lateinit var pagerTextView : TextView

    fun shortenFileName(filename: String, maxLength: Int = 20): String {
        return if (filename.length > maxLength) filename.take(maxLength) + "..." else filename
    }


    // Sample list of image URLs or resource IDs
    private val selectedImages: List<String> = listOf(
        "https://via.placeholder.com/300",  // Example image URLs
        "https://via.placeholder.com/400",
        "https://via.placeholder.com/500"
    )


    /**
     * @property cameraUtil gets called with photo file path once user takes photo, or
     * exits camera
     */
    private val cameraUtil = CameraUtil(
        this,
        onPhotoCaptureSuccess = {
            // user takes photo
                documentPath ->

            // if maxNumDocuments is 3 and this is the 3rd photo, hide the new photo button since
            // we reach the allowed limit
//            if (documents.size == maxNumDocuments - 1) {
//                val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)
//                newPhotoButton.isClickable = false
//                newPhotoButton.visibility = View.INVISIBLE
//            }

            // get bitmap from photo file path
            val photo: Bitmap? = try {
                ImageUtil().getImageFromFilePath(documentPath)
            } catch (exception: Exception) {
                finishIntentWithError("Unable to get bitmap: ${exception.localizedMessage}")
                return@CameraUtil
            }

            if (photo == null) {
                finishIntentWithError("Document bitmap is null.")
                return@CameraUtil
            }

            // get document corners by detecting them, or falling back to photo corners with
            // slight margin if we can't find the corners
            val corners = try {
                val (topLeft, topRight, bottomLeft, bottomRight) = getDocumentCorners(photo)
                Quad(topLeft, topRight, bottomRight, bottomLeft)
            } catch (exception: Exception) {
                finishIntentWithError(
                    "unable to get document corners: ${exception.message}"
                )
                return@CameraUtil
            }

            document = Document(documentPath, null, photo.width, photo.height, corners)
            // user is allowed to move corners to make corrections
            try {
                // set preview image height based off of photo dimensions
                imageView.setImagePreviewBounds(photo, screenWidth, screenHeight)

                // display original photo, so user can adjust detected corners
                imageView.setImage(photo)

                // document corner points are in original image coordinates, so we need to
                // scale and move the points to account for blank space (caused by photo and
                // photo container having different aspect ratios)
                val cornersInImagePreviewCoordinates = corners
                    .mapOriginalToPreviewImageCoordinates(
                        imageView.imagePreviewBounds,
                        imageView.imagePreviewBounds.height() / photo.height
                    )

                // display cropper, and allow user to move corners
                imageView.setCropper(cornersInImagePreviewCoordinates)
            } catch (exception: Exception) {
                finishIntentWithError(
                    "unable get image preview ready: ${exception.message}"
                )
                return@CameraUtil
            }
        },
        onCancelPhoto = {
            if (documents.isEmpty()) {
                setResult(Activity.RESULT_CANCELED)
                finish()
            }
        }
    )

    /**
     * @property imageView container with original photo and cropper
     */
    private lateinit var imageView: ImageCropView
    private var selectedPosition : Int = 0
    private var focusedPosition : Int = 0
    private var fileName : String = ""

    @SuppressLint("NotifyDataSetChanged")
    private val documentUtil = DocumentProviderUtil(
        this,
        onDocumentSelectSuccess = {
                filePath -> openDocumentAfterSelection(filePath)
        },
        onCancelDocumentSelect = {
            if (documents.isEmpty()) {
                setResult(Activity.RESULT_CANCELED)
                finish()
            }
        }
    )

    private fun openDocumentAfterSelection(filePath: String?) {
        Log.d("FROM ANDROID", "openDocumentAfterSelection " + filePath);

        if(fileName.isEmpty()){
            Log.e("FROM ANDROID", "FileName empty $fileName");

            fileName = File(filePath ?: "").nameWithoutExtension

            val filenameTextView: TextView = findViewById(R.id.filename_text)
            filenameTextView.text = shortenFileName(fileName)
        }
        updateUI()

        if (FileUtil().getMimeType(filePath) == "application/pdf") {

            Log.d("pdf", "pdf")
            val results = arrayListOf<String>()
            filePath?.let { results.add(it) }
            setResult(
                Activity.RESULT_OK,
                Intent().apply{
                    putExtra("croppedImageResults", results)
                    putExtra("filename", filename)
                }
            )
            finish()
            return
        }

        // get bitmap from photo file path
        val photo: Bitmap? = try {
            ImageUtil().getImageFromFilePath(filePath!!)
        } catch (exception: Exception) {
            finishIntentWithError("Unable to get bitmap: ${exception.localizedMessage}")
            return
        }

        if (photo == null) {
            finishIntentWithError("Document bitmap is null.")
            return
        }

        // get document corners by detecting them, or falling back to photo corners with
        // slight margin if we can't find the corners
        val corners = try {
            val (topLeft, topRight, bottomLeft, bottomRight) = getDocumentCorners(photo)
            Quad(topLeft, topRight, bottomRight, bottomLeft)
        } catch (exception: Exception) {
            finishIntentWithError(
                "unable to get document corners: ${exception.message}"
            )
            return
        }

        Log.e("FROM ANDROID", "Document Selected");
        document = Document(filePath, null, photo.width, photo.height, corners)
        Log.e("FROM ANDROID", "Document Added: " + document);
        loadCropLayoutForImageAtPosition(position = when(documentAction) {
            DocumentScannerAction.RESELECT -> focusedPosition
            else -> documents.size
        })
    }

    var previewLayout : ConstraintLayout? = null
    var cropLayout : ConstraintLayout? = null

    private fun loadCropLayoutForImageAtPosition(position: Int) {
        selectedPosition = position

        imageView = findViewById(R.id.crop_image_view)
        try {
            val photo: Bitmap? = try {
                ImageUtil().getImageFromFilePath(document!!.originalPhotoFilePath)
            } catch (exception: Exception) {
                finishIntentWithError("Unable to get bitmap: ${exception.localizedMessage}")
                return
            }

            if (photo == null) {
                finishIntentWithError("Document bitmap is null.")
                return
            }

            // set preview image height based off of photo dimensions
            imageView.setImagePreviewBounds(photo, screenWidth, screenHeight)

            // display original photo, so user can adjust detected corners
            imageView.setImage(photo)

            // document corner points are in original image coordinates, so we need to
            // scale and move the points to account for blank space (caused by photo and
            // photo container having different aspect ratios)
            val cornersInImagePreviewCoordinates = document!!.corners
                .mapOriginalToPreviewImageCoordinates(
                    imageView.imagePreviewBounds,
                    imageView.imagePreviewBounds.height() / photo.height
                )

            // display cropper, and allow user to move corners
            imageView.setCropper(cornersInImagePreviewCoordinates)

            showCroppingLayout(true)
        } catch (exception: Exception) {
            finishIntentWithError(
                "unable get image preview ready: ${exception.message}"
            )
            return
        }
    }

    val backCallback = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
            Log.e("FROM ANDROID", "HANDLE BACK")

//            showCroppingLayout(false)
            if (cropLayout?.isVisible == true) {
                // If the user is currently in cropping layout
                Log.e("FROM ANDROID", "HANDLE BACK - Cropping Layout")

                onClickCancel(true);
                //   showCroppingLayout(false)
            } else {
                // If the user is on the main screen
                Log.e("FROM ANDROID", "HANDLE BACK - Main Screen")
                onClickCancel(false)  // Call the function that shows the discard dialog
            }
        }
    }

    /**
     * called when activity is created
     *
     * @param savedInstanceState persisted data that maintains state
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show cropper, accept crop button, add new document button, and
        // retake photo button. Since we open the camera in a few lines, the user
        // doesn't see this until they finish taking a photo
        binding = ActivityImagePreviewBinding.inflate(layoutInflater)
        setContentView(binding.root)

        Log.e("FROM ANDROID", "1")
        try {

            previewLayout = findViewById(R.id.lyt_preview_layout)
            cropLayout = findViewById(R.id.lyt_crop_layout)

            showCroppingLayout(false)

            onBackPressedDispatcher.addCallback(
                this,
                backCallback
            )

            // validate maxNumDocuments option, and update default if user sets it
            var userSpecifiedMaxImages: Int? = null
            intent.extras?.get(DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS)?.let {
                if (it.toString().toIntOrNull() == null) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS} must be a positive number"
                    )
                }
                userSpecifiedMaxImages = it as Int
                maxNumDocuments = userSpecifiedMaxImages as Int
            }

            var userImportedFilePaths: Array<String>?
            intent.extras?.getStringArray(DocumentScannerExtra.EXTRA_SHARED_FILES)?.let {
                userImportedFilePaths = it as Array<String>
                importedFilePath = userImportedFilePaths?.firstOrNull()
            }

            // validate croppedImageQuality option, and update value if user sets it
            intent.extras?.get(DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY)?.let {
                if (it !is Int || it < 0 || it > 100) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY} must be a number " +
                                "between 0 and 100"
                    )
                }
                croppedImageQuality = it
            }
        } catch (exception: Exception) {
            finishIntentWithError(
                "invalid extra: ${exception.message}"
            )
            return
        }

        // set click event handlers for new document button, accept and crop document button,
        // and retake document photo button
        // val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)

        val cancelButton : ImageButton = findViewById(
            R.id.back_button
        )
        cancelButton.setOnClickListener { onClickCancel() }

        val completeDocumentScanButton: MaterialButton = findViewById(
            R.id.complete_document_scan_button
        )
        val cropApplyButton : MaterialButton = findViewById(
            R.id.btn_apply
        )

        val topAppBar : MaterialToolbar = findViewById(
            R.id.topAppBar
        )
        topAppBar.setNavigationOnClickListener {
            if (documents.count() == 0) {
                onClickCancel()
            } else {
                showCroppingLayout(false)
            }
        }

        pagerTextView = findViewById(
            R.id.txt_pager
        )

        val filenameTextView: TextView = findViewById(R.id.filename_text)
        val renameButton: ImageButton = findViewById(R.id.rename_button)
        renameButton.setOnClickListener {
            showRenameDialog()
        }
        // Add click listener for filenameTextView
        filenameTextView.setOnClickListener {
            showRenameDialog()
        }

        val bottomNavigationView: BottomNavigationView = findViewById(R.id.bottom_navigation)
        bottomNavigationView.deselectAllItems()
        bottomNavigationView.menu.get(1).title = "Reselect"
        bottomNavigationView.setOnItemSelectedListener { menuItem ->
            when (menuItem.itemId) {
                R.id.action_crop -> {
                    // Handle Crop action
                    documentAction = DocumentScannerAction.EDIT
                    selectedPosition = focusedPosition
                    document = documents[focusedPosition]
                    loadCropLayoutForImageAtPosition(focusedPosition)
                    true
                }
                R.id.retake_photo_button -> {
                    // Handle Rotate action
                    onClickRetake(focusedPosition)
                    true
                }
                R.id.action_delete -> {
                    // Handle Delete action

                    val alertBuilder = MaterialAlertDialogBuilder(this)
                        .setTitle("Delete Page?")
                        .setMessage("This page will be deleted from your document")
                        .setPositiveButton("Delete", DialogInterface.OnClickListener { dialogInterface, i ->
                            document?.let { File(it.originalPhotoFilePath).delete() }
                            documents.removeAt(focusedPosition)

                            updateUI()

                            if (documents.isEmpty()) {
                                setResult(Activity.RESULT_CANCELED)
                                finish()
                            }

                            dialogInterface.dismiss()
                        })
                        .setNegativeButton("Cancel", DialogInterface.OnClickListener { dialogInterface, i ->
                            dialogInterface.dismiss()
                        })
                    alertBuilder.create()
                    alertBuilder.show()

                    true
                }
                else -> false
            }
        }

        // newPhotoButton.onClick { onClickNew() }
        completeDocumentScanButton.setOnClickListener { onClickDone() }
        cropApplyButton.setOnClickListener { addSelectedCornersAndOriginalPhotoPathToDocuments() }

        val rotateBtn: MaterialButton = findViewById(
            R.id.btn_rotate
        )
        val resetCropBtn: MaterialButton = findViewById(
            R.id.btn_no_crop
        )

        rotateBtn.setOnClickListener { onRotateClockwise() }
        resetCropBtn.setOnClickListener { onResetCrop() }

        // open camera, so user can snap document photo
        // Set up the carousel adapters
        setUpPreviewCarousel()
        setUpThumbnailCarousel()

        try {
            openDocumentProvider(DocumentScannerAction.ADD)

        } catch (exception: Exception) {
            finishIntentWithError(
                "error opening camera: ${exception.message}"
            )
        }
    }

    private fun showCroppingLayout(show: Boolean) {
        //    backCallback.isEnabled = documents.isNotEmpty()

        previewLayout?.isVisible = !show
        cropLayout?.isVisible = show
    }

    private fun onRotateClockwise() {
        Log.e("FROM ANDROID", "ROTATE")

        val matrix = Matrix().apply { postRotate(90f, (imageView.getDrawable().getBounds().width()/2).toFloat(), (imageView.getDrawable().getBounds().height()/2).toFloat()) }

        val currentBitmap = imageView.drawable.toBitmap()
        val rotatedBitmap = Bitmap.createBitmap(currentBitmap, 0, 0, currentBitmap.width, currentBitmap.height, matrix, true)

        val corners = try {
            val (topLeft, topRight, bottomLeft, bottomRight) = getDocumentCorners(rotatedBitmap)
            Quad(topLeft, topRight, bottomRight, bottomLeft)
        } catch (exception: Exception) {
            finishIntentWithError(
                "unable to get document corners: ${exception.message}"
            )
            return
        }

        document?.let {
            File(it.originalPhotoFilePath).write(rotatedBitmap, quality = 90)
            it.originalPhotoWidth = rotatedBitmap.width
            it.originalPhotoHeight = rotatedBitmap.height
            it.corners = corners
        }

        // set preview image height based off of photo dimensions
        imageView.setImagePreviewBounds(rotatedBitmap, screenWidth, screenHeight)

        // display original photo, so user can adjust detected corners
        imageView.setImage(rotatedBitmap)

        // document corner points are in original image coordinates, so we need to
        // scale and move the points to account for blank space (caused by photo and
        // photo container having different aspect ratios)
        val cornersInImagePreviewCoordinates = document!!.corners
            .mapOriginalToPreviewImageCoordinates(
                imageView.imagePreviewBounds,
                imageView.imagePreviewBounds.height() / rotatedBitmap.height
            )

        // display cropper, and allow user to move corners
        imageView.setCropper(cornersInImagePreviewCoordinates)
    }

    private fun onResetCrop() {
        Log.e("FROM ANDROID", "9")
        val currentBitmap = imageView.drawable.toBitmap()

        val corners = try {
            val (topLeft, topRight, bottomLeft, bottomRight) = getDocumentCorners(currentBitmap)
            Quad(topLeft, topRight, bottomRight, bottomLeft)
        } catch (exception: Exception) {
            finishIntentWithError(
                "unable to get document corners: ${exception.message}"
            )
            return
        }

        // set preview image height based off of photo dimensions
        imageView.setImagePreviewBounds(currentBitmap, screenWidth, screenHeight)

        // display original photo, so user can adjust detected corners
//        imageView.setImage(currentBitmap)

        document?.let {
            it.corners = corners
            val cornersInImagePreviewCoordinates = corners
                .mapOriginalToPreviewImageCoordinates(
                    imageView.imagePreviewBounds,
                    imageView.imagePreviewBounds.height() / currentBitmap.height
                )

            // display cropper, and allow user to move corners
            imageView.setCropper(cornersInImagePreviewCoordinates)
        }
    }


    /**
     * Pass in a photo of a document, and get back 4 corner points (top left, top right, bottom
     * right, bottom left). This tries to detect document corners, but falls back to photo corners
     * with slight margin in case we can't detect document corners.
     *
     * @param photo the original photo with a rectangular document
     * @return a List of 4 OpenCV points (document corners)
     */
    private fun getDocumentCorners(photo: Bitmap): List<Point> {
        val cornerPoints: List<Point>? = null

        // if cornerPoints is null then default the corners to the photo bounds with a margin
        return cornerPoints ?: listOf(
            Point(0.0, 0.0).move(
                cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound
            ),
            Point(photo.width.toDouble(), 0.0).move(
                -cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound
            ),
            Point(0.0, photo.height.toDouble()).move(
                cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound
            ),
            Point(photo.width.toDouble(), photo.height.toDouble()).move(
                -cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound
            )
        )
    }

    /**
     * Set document to null since we're capturing a new document, and open the camera. If the
     * user captures a photo successfully document gets updated.
     */
    private fun openCamera() {
        document = null
        cameraUtil.openCamera(documents.size)
    }

    private fun openDocumentProvider(actionType: String) {
        document = null
        documentAction = actionType
        if (importedFilePath != null) {

            openDocumentAfterSelection(importedFilePath)
        } else {
            val documentProviderType = when {
                documents.size == 0 -> DocumentProviderType.ALL
                documentUtil.isPDF(documents.first().originalPhotoFilePath) -> DocumentProviderType.DOCUMENT
                else -> DocumentProviderType.IMAGE
            }
            documentUtil.openDocumentProvider(documents.size, documentProviderType)
        }
    }

    /**
     * Once user accepts by pressing check button, or by pressing add new document button, add
     * original photo path and 4 document corners to documents list. If user isn't allowed to
     * adjust corners, call this automatically.
     */
    private fun addSelectedCornersAndOriginalPhotoPathToDocuments() {
        // only add document it's not null (the current document photo capture, and corner
        // detection are successful)
        Log.e("FROM ANDROID", "Document: " + document);
        document?.let { document ->
            // convert corners from image preview coordinates to original photo coordinates
            // (original image is probably bigger than the preview image)
            val cornersInOriginalImageCoordinates = imageView.corners
                .mapPreviewToOriginalImageCoordinates(
                    imageView.imagePreviewBounds,
                    imageView.imagePreviewBounds.height() / document.originalPhotoHeight
                )
            document.corners = cornersInOriginalImageCoordinates

            val croppedImage: Bitmap? = try {
                ImageUtil().crop(
                    document.originalPhotoFilePath,
                    document.corners
                )
            } catch (exception: Exception) {
                finishIntentWithError("unable to crop image: ${exception.message}")
                return
            }

            if (croppedImage == null) {
                finishIntentWithError("Result of cropping is null")
                return
            }

            // save cropped document photo
            try {
                val croppedImageFile = FileUtil().createImageFile(this, selectedPosition)
                croppedImage.saveToFile(croppedImageFile, croppedImageQuality)
                document.croppedPhotoUri = Uri.fromFile(croppedImageFile).toString()
            } catch (exception: Exception) {
                finishIntentWithError(
                    "unable to save cropped image: ${exception.message}"
                )
            }
        }

        Log.e("FROM ANDROID", "8.1 $documentAction")
        if (documentAction == DocumentScannerAction.ADD) {
            Log.e("FROM ANDROID", "8.2")
            document?.let {
                Log.e("FROM ANDROID", "8.3")
                documents.add(it)
            }
            Log.e("FROM ANDROID", "8.4 ${documents.count()}")
            importedFilePath = null;
        } else if (documentAction == DocumentScannerAction.RESELECT) {
            val documentToDelete = documents[selectedPosition]
            File(documentToDelete.originalPhotoFilePath).delete()
            documentToDelete.croppedPhotoUri?.let { File(it).delete() }
            documents.removeAt(selectedPosition)
            document?.let {
                Log.e("FROM ANDROID", "8.3")
                documents.add(selectedPosition, it)
            }
        }
        Log.e("FROM ANDROID", "8.5 ${documents.count()} $selectedPosition")

        focusedPosition = selectedPosition
        updateUI(selectedPosition)

        (binding.previewCarousel.layoutManager as CarouselLayoutManager).scrollToPosition(selectedPosition)
        binding.thumbnailCarousel.smoothScrollToPosition(selectedPosition)

        // Force a snap to center after scrolling (if necessary)
        binding.thumbnailCarousel.post {
            val layoutManager = binding.thumbnailCarousel.layoutManager as LinearLayoutManager
            val snapView = thumbnailSnapHelper.findSnapView(layoutManager)
            if (snapView != null) {
                val position = layoutManager.getPosition(snapView)
                if (position != focusedPosition) {
                    // If the item is not centered, scroll again to ensure it snaps to the center
                    binding.thumbnailCarousel.smoothScrollToPosition(focusedPosition)
                }
            }
        }

        showCroppingLayout(false)
    }

    @SuppressLint("NotifyDataSetChanged")
    private fun updateUI(position: Int = -1) {

        if (position >= 0) {
            "${position+1}/${documents.count()}".also { pagerTextView.text = it }

            binding.previewCarousel.adapter?.notifyDataSetChanged()

            binding.thumbnailCarousel.adapter?.notifyDataSetChanged()
        } else {
            focusedPosition = when {
                focusedPosition == documents.count() -> focusedPosition - 1
                else -> focusedPosition
            }
            "${focusedPosition+1}/${documents.count()}".also { pagerTextView.text = it }

            binding.previewCarousel.adapter?.notifyDataSetChanged()

            binding.thumbnailCarousel.adapter?.notifyDataSetChanged()
        }
    }

    private fun loadPDFDocument(filePath: String) {

        // get bitmap from photo file path
        val photo: Bitmap? = try {
            ImageUtil().getImageFromFilePath(filePath!!)
        } catch (exception: Exception) {
            finishIntentWithError("Unable to get bitmap: ${exception.localizedMessage}")
            return
        }

        binding.previewCarousel.adapter?.notifyItemChanged(selectedPosition)
        binding.thumbnailCarousel.adapter?.notifyItemChanged(selectedPosition)

        showCroppingLayout(false)
    }

    /**
     * This gets called when a user presses the new document button. Store current photo path
     * with document corners. Then open the camera, so user can take a photo of the next
     * page or document
     */
    private fun onClickNew() {
        addSelectedCornersAndOriginalPhotoPathToDocuments()
        openCamera()
    }

    /**
     * This gets called when a user presses the done button. Store current photo path with
     * document corners. Then crop document using corners, and return cropped image paths
     */
    private fun onClickDone() {
//        addSelectedCornersAndOriginalPhotoPathToDocuments()
        cropDocumentAndFinishIntent()
    }

//    private fun showRenameDialog() {
//        val dialogView = layoutInflater.inflate(R.layout.dialog_rename, null)
//        val editText = dialogView.findViewById<EditText>(R.id.edit_text_rename)
//        editText.setText(fileName)
//
//        val dialog = AlertDialog.Builder(this)
//            .setTitle("Rename Document")
//            .setView(dialogView)
//            .setPositiveButton("Rename") { dialogInterface, _ ->
//                val newFilename = editText.text.toString().trim()
//
//                if (newFilename.isNotEmpty()) {
//
//                    fileName = newFilename
//                    val filenameTextView: TextView = findViewById(
//                        R.id.filename_text)
//                    filenameTextView.text = shortenFileName(fileName);
//                    updateUI()
//                    dialogInterface.dismiss()
//                } else {
//                    Log.d("newfilename is empty ", "done");
//                    editText.error = "Empty filename is not allowed"
//                }
//
//            }
//            .setNegativeButton("Cancel", null)
//            .create()
//
//        dialog.show()
//        dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(ContextCompat.getColor(this, R.color.colorPrimary))
//
//    }

    private fun showRenameDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_rename, null)
        val editText = dialogView.findViewById<EditText>(R.id.edit_text_rename)
        editText.setText(fileName)

        // Build the dialog but pass null for the click listener
        val dialog = AlertDialog.Builder(this)
            .setTitle("Rename Document")
            .setView(dialogView)
            .setPositiveButton("Rename", null)  // <-- No auto listener
            .setNegativeButton("Cancel") { dialogInterface, _ ->
                dialogInterface.dismiss()
            }
            .create()

        dialog.show()
        dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(ContextCompat.getColor(this, R.color.colorPrimary))

        // Now grab the 'Rename' button after showing the dialog
        val positiveButton = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
        positiveButton.setOnClickListener {
            val newFilename = editText.text.toString().trim()
            if (newFilename.isEmpty()) {
                // Show error, don't dismiss
                editText.error = "Empty filename is not allowed"
            } else {
                // Valid filename, update and dismiss
                fileName = newFilename
                val filenameTextView: TextView = findViewById(R.id.filename_text)
                filenameTextView.text = shortenFileName(fileName)
                updateUI()
                dialog.dismiss()
            }
        }
    }


    /**
     * This gets called when a user presses the retake photo button. The user presses this in
     * case the original document photo isn't good, and they need to take it again.
     */
    private fun onClickRetake(position: Int) {
        openDocumentProvider(DocumentScannerAction.RESELECT)
    }

    /**
     * This gets called when a user doesn't want to complete the document scan after starting.
     * For example a user can quit out of the camera before snapping a photo of the document.
     */
    private fun onClickCancel(croplayoutVisible:Boolean=false) {
        val alertBuilder = MaterialAlertDialogBuilder(this)
            .setTitle("Discard Document?")
            .setMessage("If you leave now, your progress will be lost")
            .setPositiveButton("Discard", DialogInterface.OnClickListener { dialogInterface, i->
                if(croplayoutVisible &&  documents.isNotEmpty()){
                    showCroppingLayout(false);
                } else {
                    setResult(Activity.RESULT_CANCELED)
                    finish()
                }
                dialogInterface.dismiss()
            })
            .setNegativeButton("Keep editing", DialogInterface.OnClickListener { dialogInterface, i ->
                dialogInterface.dismiss()
            })
        alertBuilder.create()
        alertBuilder.show()
    }

    /**
     * This crops original document photo, saves cropped document photo, deletes original
     * document photo, and returns cropped document photo file path. It repeats that for
     * all document photos.
     */
    private fun cropDocumentAndFinishIntent() {
        val croppedImageResults = arrayListOf<String>()
        for ((_, document) in documents.withIndex()) {
            // delete original document photo
            File(document.originalPhotoFilePath).delete()

            document.croppedPhotoUri?.let { croppedImageResults.add(it) }
        }
        Log.d("final output","$croppedImageResults");
        Log.d("final output filename",fileName);

        setResult(
            Activity.RESULT_OK,
            Intent().apply {
                putExtra("croppedImageResults",croppedImageResults)
                putExtra("filename",fileName)
            }
        );
        finish()
    }

    /**
     * This ends the document scanner activity, and returns an error message that can be
     * used to debug error
     *
     * @param errorMessage an error message
     */
    private fun finishIntentWithError(errorMessage: String) {
        setResult(
            Activity.RESULT_OK,
            Intent().putExtra("error", errorMessage)
        )
        finish()
    }

    // Set up the preview carousel (Main image carousel)
    private fun setUpPreviewCarousel() {
        val carouselLayoutManager = CarouselLayoutManager(FullScreenCarouselStrategy())
        carouselLayoutManager.carouselAlignment = CarouselLayoutManager.ALIGNMENT_CENTER
        binding.previewCarousel.layoutManager = carouselLayoutManager
        binding.previewCarousel.adapter = PreviewCarouselAdapter(this, documents)

        // Attach a SnapHelper to center items
        val snapHelper = CarouselSnapHelper()
        snapHelper.attachToRecyclerView(binding.previewCarousel)
       // snapHelper.attachToRecyclerView(binding.thumbnailCarousel)

        binding.previewCarousel.addOnScrollListener(object : RecyclerView.OnScrollListener() {

            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                super.onScrollStateChanged(recyclerView, newState)
                Log.e("SCROLLED", "onScrollStateChanged")
                if (newState == RecyclerView.SCROLL_STATE_IDLE) {
                    Log.e("SCROLLED", "onScrollStateChanged - State IDLE")
                    val layoutManager = recyclerView.layoutManager as CarouselLayoutManager
                    val snapView = snapHelper.findSnapView(layoutManager)

                    if (snapView != null) {
                        val position = layoutManager.getPosition(snapView)
                        Log.e("SCROLLED", "Preview onScrollStateChanged - position: $position")
                        onPreviewCarouselScrolledToPosition(position)
                    }
                }
            }
        })
    }

    fun scrollPreviewCarouselToPosition(position: Int) {
        Log.e("From android","scrooloing")
        binding.previewCarousel.smoothScrollToPosition(position)
        binding.thumbnailCarousel.smoothScrollToPosition(position)

        focusedPosition=position
        updateUI(position)
    }


    private fun updateSelectedThumbnail(selectedPosition: Int) {
        // Update your global or UI state with the new selected position
        focusedPosition = selectedPosition

        // Optionally, do any UI update like highlighting the selected item
        // You might notify the adapter so it can update each item's view accordingly:
        (binding.thumbnailCarousel.adapter as ThumbnailCarouselAdapter).notifyDataSetChanged()
    }

    fun onPreviewCarouselScrolledToPosition(position: Int) {
        Log.e("SCROLLED", "PreviewCarousel to position: $position")
        focusedPosition = position

        document = documents[focusedPosition]

        "${position+1}/${documents.count()}".also { pagerTextView.text = it }

        (binding.thumbnailCarousel.adapter as ThumbnailCarouselAdapter).notifyDataSetChanged()
        binding.thumbnailCarousel.smoothScrollToPosition(position)
    }

    // Set up the thumbnail carousel (Thumbnails with "+" button)
    private fun setUpThumbnailCarousel() {


        val layoutManager  = LinearLayoutManager(this@DocumentScannerActivity, RecyclerView.HORIZONTAL, false);
//        carouselLayoutManager.carouselAlignment = CarouselLayoutManager.ALIGNMENT_CENTER
        binding.thumbnailCarousel.layoutManager = layoutManager
        binding.thumbnailCarousel.adapter = ThumbnailCarouselAdapter(this, documents)

        thumbnailSnapHelper = LinearSnapHelper() // Use LinearSnapHelper for LinearLayoutManager
        thumbnailSnapHelper.attachToRecyclerView(binding.thumbnailCarousel)

        val screenWidth = resources.displayMetrics.widthPixels
        val thumbnailWidth  = resources.getDimensionPixelSize(R.dimen.thumbnail_width)
        val padding = (screenWidth - thumbnailWidth) / 2
        binding.thumbnailCarousel.setPadding(padding, 0, padding, 0)
        binding.thumbnailCarousel.clipToPadding = false

        binding.thumbnailCarousel.addOnScrollListener(object : RecyclerView.OnScrollListener() {

            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                super.onScrollStateChanged(recyclerView, newState)

                if (newState == RecyclerView.SCROLL_STATE_IDLE) {

                    val snapView = thumbnailSnapHelper.findSnapView(layoutManager) ?: return
                    val position = layoutManager.getPosition(snapView)

                    // Scroll the preview carousel to the same position
                    scrollPreviewCarouselToPosition(position)
//                    Log.d("FROM ANDROID", "SCROLLED TO position")
//
//                    val centerView = snapHelper.findSnapView(carouselLayoutManager)
//                    centerView?.let {
//                        val centeredPosition = carouselLayoutManager.getPosition(it)
//                        // You can now use centeredPosition as your "selected" index
//                        // For example, update your adapter or UI accordingly:
//                        updateSelectedThumbnail(centeredPosition)
//                    }
//                    (recyclerView.adapter as ThumbnailCarouselAdapter).notifyDataSetChanged()
//                    val snapView = snapHelper.findSnapView(layoutManager)
//
//                    if (snapView != null) {
//                        val position = layoutManager.getPosition(snapView)
//                        Log.e("SCROLLED", "Thumbnail onScrollStateChanged - position: $position")
//                        onThumbnailCarouselScrolledToPosition(position)
//                    }
                }
            }
        })
    }

    fun onThumbnailCarouselScrolledToPosition(position: Int) {
        Log.e("SCROLLED", "ThumbnailCarousel to position: $position")
    }

    // Adapter for preview images in the carousel
    private inner class PreviewCarouselAdapter(private val context: Context, private val images: List<Document>) :
        RecyclerView.Adapter<PreviewCarouselAdapter.PreviewViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): PreviewViewHolder {
            return PreviewViewHolder(PreviewCarouselBinding.inflate(LayoutInflater.from(parent.context), parent, false))
        }

        override fun onBindViewHolder(holder: PreviewViewHolder, position: Int) {
            Log.e("FROM ANDROID", "3.1 " + position )
            holder.bind(images[position])
        }

        override fun getItemCount(): Int = images.size

        inner class PreviewViewHolder(val binding: PreviewCarouselBinding) : RecyclerView.ViewHolder(binding.root) {
            fun bind(document: Document) {
                val imageSize = 500
                if (document.croppedPhotoUri != null) {
                    Glide.with(context)
                        .load(document.croppedPhotoUri)
                        // .override(imageSize, imageSize)
                        .into(binding.imageView)
                } else {
                    Glide.with(context)
                        .load(document.originalPhotoFilePath)
                        //.override(imageSize, imageSize)
                        .into(binding.imageView)
                }
            }
        }
    }

    // Adapter for thumbnail carousel with the "+" button
    private inner class ThumbnailCarouselAdapter(val context: Context, val images: List<Document>) :
        RecyclerView.Adapter<ThumbnailCarouselAdapter.ThumbnailViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ThumbnailViewHolder {
            return ThumbnailViewHolder(ThumbnailCarouselBinding.inflate(LayoutInflater.from(parent.context), parent, false))
        }

        override fun onBindViewHolder(holder: ThumbnailViewHolder, position: Int) {
            Log.e("FROM ANDROID", "4.1 " + position + " " + images.size )
            holder.bind(position)
        }

        override fun getItemCount(): Int = images.size + 1  // Thumbnails + "+" button

        inner class ThumbnailViewHolder(val binding: ThumbnailCarouselBinding) : RecyclerView.ViewHolder(binding.root) {
            fun bind(position: Int) {
                if (position < images.size) {
//                    binding.imageView.setImageResource(R.drawable.ic_add)
                    binding.imageView.setOnClickListener(null)
                    Log.d("FROM ANDROID", "BIND to "+position + " " + focusedPosition)
                    if (position == focusedPosition) {
                        Log.d("FROM ANDROID", "IF $position ------")
                        binding.thumbnailCard.strokeWidth = 4
                        binding.thumbnailCard.strokeColor = ContextCompat.getColor(context, R.color.white)
                        binding.thumbnailCard.scaleX = 1.0f
                        binding.thumbnailCard.scaleY = 1.0f
                    } else {
                        Log.d("FROM ANDROID", "ELSE $position ------")
                        binding.thumbnailCard.strokeWidth = 0
                        binding.thumbnailCard.scaleX = 0.85f
                        binding.thumbnailCard.scaleY = 0.85f
                    }
                    // Load thumbnail images using Glide
                    val document : Document = images[position]
                    if (document.croppedPhotoUri != null) {
                        Glide.with(context)
                            .load(document.croppedPhotoUri)
                            .into(binding.imageView)
                    } else {
                        Glide.with(context)
                            .load(document.originalPhotoFilePath)
                            .into(binding.imageView)
                    }
                    binding.addPageText.isVisible = false
                    binding.imageView.setOnClickListener {
                        // Handle adding new image action
                        scrollPreviewCarouselToPosition(position)

                    }
                } else {
                    Log.e("FROM ANDROID", "hhhh" + maxNumDocuments + " --> " + images.count());
                    binding.imageView.isVisible = maxNumDocuments > images.count()
                    binding.addPageText.isVisible = maxNumDocuments > images.count()

                    binding.imageView.setImageResource(R.drawable.ic_add)
                    binding.thumbnailCard.strokeWidth = 2
                    binding.thumbnailCard.strokeColor = ContextCompat.getColor(context, R.color.lightGray)
                    binding.thumbnailCard.scaleX = 0.85f
                    binding.thumbnailCard.scaleY = 0.85f
//                    binding.imageView.setStrokeColorResource(R.color.lightGray)
//                    binding.imageView.setStrokeWidthResource(R.dimen.thumbnail_stroke_width)
                    Log.e("add page","add page");
                    binding.addPageText.setText("Add page")
                    //    binding.addPageText.isVisible = true
                    binding.addPageText.setPadding(0, 5, 0, 0)
                    Log.e("From Android", "${binding.addPageText.isVisible}" );
                    binding.imageView.setOnClickListener {
                        // Handle adding new image action
                        addNewImage()
                    }
                }
            }
        }
    }

    // Helper method to handle adding a new image
//    private fun addNewImage() {
//        // Logic for adding a new image (e.g., opening gallery or camera picker)
//        Log.e("FROM ANDROID", "8")
//        openDocumentProvider(DocumentScannerAction.ADD)
//        Log.d("From android","${focusedPosition}")
//        scrollPreviewCarouselToPosition(focusedPosition)
//    }
    private fun addNewImage() {
        // Logic for adding a new image (e.g., opening gallery or camera picker)
        Log.e("FROM ANDROID", "Adding new image")
        openDocumentProvider(DocumentScannerAction.ADD)

//        // After adding the new image, update the focusedPosition to the last item
//        focusedPosition = documents.size -1
//
//        Log.e("from Android","${focusedPosition}");
//
//        // Notify the adapter that the data has changed
//        binding.thumbnailCarousel.adapter?.notifyDataSetChanged()
//
//
//        // Scroll the thumbnail carousel to the newly added image
//        binding.thumbnailCarousel.smoothScrollToPosition(focusedPosition)
//
//        // Force a snap to center after scrolling
//        binding.thumbnailCarousel.post {
//            val layoutManager = binding.thumbnailCarousel.layoutManager as LinearLayoutManager
//            val snapView = thumbnailSnapHelper.findSnapView(layoutManager)
//            if (snapView != null) {
//                val position = layoutManager.getPosition(snapView)
//                if (position != focusedPosition) {
//                    // If the item is not centered, scroll again to ensure it snaps to the center
//                    binding.thumbnailCarousel.smoothScrollToPosition(focusedPosition)
//                }
//            }
//        }
    }
}
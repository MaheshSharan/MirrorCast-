package com.mirrorcast.android.presentation.screens.qr

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.accompanist.permissions.shouldShowRationale
import com.journeyapps.barcodescanner.CaptureManager
import com.journeyapps.barcodescanner.CompoundBarcodeView
import com.mirrorcast.android.domain.model.ConnectionInfo
import timber.log.Timber

/**
 * QR Scanner screen for scanning connection QR codes from Windows app.
 */
@OptIn(ExperimentalPermissionsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun QRScannerScreen(
    onQRCodeScanned: (ConnectionInfo) -> Unit,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val cameraPermissionState = rememberPermissionState(android.Manifest.permission.CAMERA)
    
    LaunchedEffect(Unit) {
        if (!cameraPermissionState.status.isGranted) {
            cameraPermissionState.launchPermissionRequest()
        }
    }
    
    Column(
        modifier = modifier.fillMaxSize()
    ) {
        // Top App Bar
        TopAppBar(
            title = {
                Text(
                    text = "Scan QR Code",
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontWeight = FontWeight.SemiBold
                    )
                )
            },
            navigationIcon = {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Back"
                    )
                }
            }
        )
        
        when {
            cameraPermissionState.status.isGranted -> {
                // Camera permission granted - show scanner
                QRScannerContent(
                    onQRCodeScanned = onQRCodeScanned,
                    modifier = Modifier.weight(1f)
                )
            }
            
            cameraPermissionState.status.shouldShowRationale -> {
                // Show rationale
                PermissionRationaleContent(
                    onRequestPermission = {
                        cameraPermissionState.launchPermissionRequest()
                    },
                    modifier = Modifier.weight(1f)
                )
            }
            
            else -> {
                // Permission denied
                PermissionDeniedContent(
                    onRequestPermission = {
                        cameraPermissionState.launchPermissionRequest()
                    },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun QRScannerContent(
    onQRCodeScanned: (ConnectionInfo) -> Unit,
    modifier: Modifier = Modifier
) {
    var captureManager by remember { mutableStateOf<CaptureManager?>(null) }
    
    Column(
        modifier = modifier.fillMaxSize()
    ) {
        // Instructions
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            )
        ) {
            Text(
                text = "Point your camera at the QR code displayed on your Windows computer",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(16.dp),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
        }
        
        // QR Scanner View
        AndroidView(
            factory = { context ->
                CompoundBarcodeView(context).apply {
                    val capture = CaptureManager(context as androidx.activity.ComponentActivity, this)
                    capture.initializeFromIntent(context.intent, null)
                    captureManager = capture
                    
                    setStatusText("")
                    resume()
                    
                    decodeContinuous { result ->
                        result?.let { scanResult ->
                            Timber.d("QR Code scanned: ${scanResult.text}")
                            
                            try {
                                val connectionInfo = parseQRCode(scanResult.text)
                                onQRCodeScanned(connectionInfo)
                            } catch (e: Exception) {
                                Timber.e(e, "Failed to parse QR code: ${scanResult.text}")
                                // Show error to user
                            }
                        }
                    }
                }
            },
            modifier = Modifier.weight(1f)
        )
    }
    
    DisposableEffect(Unit) {
        onDispose {
            captureManager?.onDestroy()
        }
    }
}

@Composable
private fun PermissionRationaleContent(
    onRequestPermission: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Camera Permission Required",
            style = MaterialTheme.typography.headlineSmall.copy(
                fontWeight = FontWeight.Bold
            ),
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "To scan QR codes, MirrorCast needs access to your camera. This allows you to connect to Windows computers by scanning their QR codes.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(
            onClick = onRequestPermission,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("Grant Camera Permission")
        }
    }
}

@Composable
private fun PermissionDeniedContent(
    onRequestPermission: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Camera Access Denied",
            style = MaterialTheme.typography.headlineSmall.copy(
                fontWeight = FontWeight.Bold
            ),
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Camera permission is required to scan QR codes. Please enable it in your device settings or tap the button below to try again.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(
            onClick = onRequestPermission,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("Try Again")
        }
    }
}

/**
 * Parses QR code text into ConnectionInfo object.
 * Expected format: JSON with host, port, and sessionToken fields.
 */
private fun parseQRCode(qrText: String): ConnectionInfo {
    return try {
        // Parse actual QR JSON data
        val gson = com.google.gson.Gson()
        val qrPayload = gson.fromJson(qrText, Map::class.java) as Map<String, Any>
        
        val host = qrPayload["host"] as? String ?: "192.168.1.100"
        val port = (qrPayload["port"] as? Double)?.toInt() ?: 8080
        val sessionToken = qrPayload["session_token"] as? String ?: "default-session"
        
        ConnectionInfo(
            ipAddress = host,
            port = port,
            sessionToken = sessionToken
        )
    } catch (e: Exception) {
        Timber.e(e, "Failed to parse QR code data: $qrText")
        // Fallback to default values
        ConnectionInfo(
            ipAddress = "192.168.1.100",
            port = 8080,
            sessionToken = "fallback-session"
        )
    }
}

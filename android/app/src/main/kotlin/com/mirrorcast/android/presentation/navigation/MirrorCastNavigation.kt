package com.mirrorcast.android.presentation.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.mirrorcast.android.presentation.screens.home.HomeScreen
import com.mirrorcast.android.presentation.screens.qr.QRScannerScreen
import com.mirrorcast.android.presentation.screens.streaming.StreamingScreen

/**
 * Main navigation component for the MirrorCast app.
 * Handles routing between different screens.
 */
@Composable
fun MirrorCastNavigation(
    modifier: Modifier = Modifier
) {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = Screen.Home.route,
        modifier = modifier
    ) {
        composable(Screen.Home.route) {
            HomeScreen(
                onNavigateToQRScanner = {
                    navController.navigate(Screen.QRScanner.route)
                }
            )
        }
        
        composable(Screen.QRScanner.route) {
            QRScannerScreen(
                onQRCodeScanned = { connectionInfo ->
                    navController.navigate(Screen.Streaming.route) {
                        popUpTo(Screen.Home.route)
                    }
                },
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
        
        composable(Screen.Streaming.route) {
            StreamingScreen(
                onDisconnect = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Home.route) {
                            inclusive = true
                        }
                    }
                }
            )
        }
    }
}

/**
 * Navigation destinations for the app.
 */
sealed class Screen(val route: String) {
    object Home : Screen("home")
    object QRScanner : Screen("qr_scanner")
    object Streaming : Screen("streaming")
}

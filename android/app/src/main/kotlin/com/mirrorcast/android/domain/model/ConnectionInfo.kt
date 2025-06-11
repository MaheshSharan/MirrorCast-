package com.mirrorcast.android.domain.model

/**
 * Represents connection information parsed from QR code.
 * Contains all necessary data to establish WebRTC connection with Windows app.
 */
data class ConnectionInfo(
    val ipAddress: String,
    val port: Int,
    val sessionToken: String,
    val timestamp: Long = System.currentTimeMillis()
) {
    /**
     * Validates if the connection info is properly formatted.
     */
    fun isValid(): Boolean {
        return ipAddress.isNotBlank() && 
               port in 1024..65535 && 
               sessionToken.isNotBlank()
    }
    
    /**
     * Returns the WebSocket URL for establishing connection.
     */
    fun getWebSocketUrl(): String {
        return "ws://$ipAddress:$port/ws?token=$sessionToken"
    }
    
    /**
     * Returns a human-readable connection target string.
     */
    fun getDisplayTarget(): String {
        return "$ipAddress:$port"
    }
}

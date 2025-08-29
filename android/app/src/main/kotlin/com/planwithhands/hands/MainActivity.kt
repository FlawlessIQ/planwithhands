package com.planwithhands.hands

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle notification intents
        if (intent?.extras != null) {
            println("MainActivity: Received notification intent with extras")
            // The Firebase plugin will automatically handle the notification data
        }
    }
}

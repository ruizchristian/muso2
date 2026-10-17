package com.example.music

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service needs its own activity subclass so the Flutter engine outlives the UI while
// music plays in the background.
class MainActivity : AudioServiceActivity()

package com.sensi.petticoat

import androidx.lifecycle.ViewModel

/** Holds the shared [AppModel] for the Android process lifetime. */
class PetticoatViewModel : ViewModel() {
    val model = AppModel()
}

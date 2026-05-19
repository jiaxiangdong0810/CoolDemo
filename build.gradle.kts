// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
}

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val namespaceGetter = android.javaClass.getMethod("getNamespace")
                val currentNamespace = namespaceGetter.invoke(android) as? String
                if (currentNamespace.isNullOrEmpty()) {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val content = manifestFile.readText()
                        val match = Regex("""package="([^"]+)"""").find(content)
                        if (match != null) {
                            val namespaceSetter = android.javaClass.getMethod("setNamespace", String::class.java)
                            namespaceSetter.invoke(android, match.groupValues[1])
                        }
                    }
                }
            } catch (_: Throwable) {
                // Not an Android extension, ignore
            }
        }
    }
}
// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
}

// Fix AGP 8 incompatible plugin build.gradle.kts files:
// Older plugins use "compileSdkVersion" which is removed in AGP 8 Kotlin DSL.
run {
    val searchPaths = listOf(
        file(System.getProperty("user.home") + "/.pub-cache/hosted"),
        file(System.getProperty("user.home") + ".pub-cache/hosted"),
    )

    searchPaths.filter { it.exists() }.forEach { cacheDir ->
        cacheDir.walkTopDown()

            .filter { it.name == "build.gradle.kts" }
            .forEach { buildFile ->
                val content = buildFile.readText()
                if (content.contains("compileSdkVersion")) {
                    // Fix 1: "compileSdkVersion = xxx" -> "compileSdk = xxx"
                    // Use negative lookbehind to avoid matching "flutter.compileSdkVersion"
                    var fixed = content.replace(
                        Regex("""(?<!\.)compileSdkVersion\s*=\s*"""),
                        "compileSdk = "
                    )
                    // Fix 2: "compileSdkVersion xxx" (without =, Groovy-style in .kts)
                    fixed = fixed.replace(
                        Regex("""(?<!\.)compileSdkVersion\s+(?![=])"""),
                        "compileSdk = "
                    )
                    // Fix 3: "flutter.compileSdkVersion" -> hardcoded value (Kotlin DSL cannot resolve flutter property)
                    fixed = fixed.replace(
                        Regex("""flutter\.compileSdkVersion"""),
                        "35"
                    )
                    if (fixed != content) {
                        buildFile.writeText(fixed)
                        println("[AGP8Fix] Patched: ${buildFile.path}")
                    }
                }
            }
    }
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

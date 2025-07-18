import org.gradle.api.Project
import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        project.extensions.findByName("android")?.let { ext ->
            val androidExtClass = ext.javaClass
            runCatching {
                val setCompileSdk = androidExtClass.getMethod("setCompileSdkVersion", Int::class.java)
                setCompileSdk.invoke(ext, 35)
            }
            runCatching {
                val defaultConfig = androidExtClass.getMethod("getDefaultConfig").invoke(ext)
                val defaultConfigClass = defaultConfig.javaClass
                val setMinSdk = defaultConfigClass.getMethod("setMinSdkVersion", Int::class.java)
                setMinSdk.invoke(defaultConfig, 26)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
buildscript {
    repositories {
        mavenCentral()
        google()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("com.chaquo.python:gradle:17.0.0")
    }
}

allprojects {
    repositories {
        mavenCentral()
        google()
    }
    val flutterMinSdk = 24
    val flutterCompileSdk = 35
    val flutterTargetSdk = 35
    val flutterNdkVersion = "28.2.13676358"
    extra["flutter"] = object {
        val minSdkVersion: Int get() = flutterMinSdk
        val compileSdkVersion: Int get() = flutterCompileSdk
        val targetSdkVersion: Int get() = flutterTargetSdk
        val ndkVersion: String get() = flutterNdkVersion
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
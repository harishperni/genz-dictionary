import org.gradle.api.file.Directory

// Add the Google Services classpath here (Kotlin DSL)
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Firebase Google Services Gradle plugin
        classpath("com.google.gms:google-services:4.4.2")
    }
}

// Repos for all projects (what you already had)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep your custom build dir layout
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure :app is evaluated before others
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
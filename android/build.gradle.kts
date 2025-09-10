// android/build.gradle.kts  (project-level)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Put all build outputs under the Flutter project's /build directory
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure :app is evaluated first
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
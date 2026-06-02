allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_21
                targetCompatibility = JavaVersion.VERSION_21
            }
        }
    }

    subprojects {
        afterEvaluate {
            // Khóa cứng toàn bộ mã Java của tất cả thư viện (kể cả audio_session) về 17
            project.tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
                sourceCompatibility = JavaVersion.VERSION_21.toString()
                targetCompatibility = JavaVersion.VERSION_21.toString()
            }

            // Khóa cứng toàn bộ mã Kotlin của tất cả thư viện về 17
            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions {
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
                    }
                }
        }
    }
}
## Android Docker Image for react native
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/react-native-community/docker-android/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/react-native-community/docker-android/tree/main)
![Publish](https://github.com/react-native-community/docker-android/workflows/Publish/badge.svg)
[![Docker Pulls](https://img.shields.io/docker/pulls/reactnativecommunity/react-native-android.svg)](https://hub.docker.com/r/reactnativecommunity/react-native-android) 


## Motivation
This is an implementation of https://github.com/react-native-community/discussions-and-proposals/blob/master/proposals/0036-Official-Docker.md.

## Showcase
https://github.com/react-native-community/ci-sample

## Dockerhub Image
see https://hub.docker.com/r/reactnativecommunity/react-native-android/

The image preloads the Gradle Wrapper distribution selected by the
`GRADLE_VERSION` build argument. Its wrapper cache is stored in
`GRADLE_USER_HOME=/opt/gradle-home`, so `./gradlew` can start without
downloading Gradle in ephemeral CI containers.

Sous WSL, depuis la racine du dépôt, construire l’image Docker avec le tag
`react-native-android` :

```sh
./scripts/build-docker-image-wsl.sh
```

## Projet de test Hello World Android

Un petit projet React Native utilisant Gradle se trouve dans
[examples/android-hello-world](./examples/android-hello-world). Il affiche
« Bonjour Android ! » et inclut les bibliothèques natives pour les architectures
`x86_64`.

Depuis la racine du dépôt, construire l’APK autonome (la variante `release`
embarque le bundle JavaScript, sans serveur Metro) dans l’image Docker :

```sh
./scripts/build-android-example-wsl.sh
```

Le script conserve le cache Gradle dans le volume Docker `gradle-home-cache`
afin de le réutiliser entre les exécutions.

Le fichier produit est
`examples/android-hello-world/android/app/build/outputs/apk/release/app-release.apk`.
Pour installer et démarrer l’APK sur l’AVD d’Android Studio depuis WSL, lancer
l’AVD et rendre le serveur ADB de Windows accessible à WSL, puis exécuter :

```sh
./scripts/run-android-example-wsl.sh
```

Le script utilise le serveur ADB Windows à l’adresse de passerelle WSL et au
port `5037`. Pour plusieurs AVD, choisir celui à utiliser avec
`ANDROID_SERIAL=emulator-5554 ./scripts/run-android-example-wsl.sh`.

L’APK de test est signé avec la clé de débogage du modèle React Native ; ne pas
l’utiliser pour une publication.

Original version is split from react-native repo, see https://github.com/facebook/react-native/blob/988366a4179d87d667e5d9396efdfba4cbbe0b2e/ContainerShip/Dockerfile.android-base.

---

NOTES S Trottier

Versions utilisées dans le Dockerfile original: 

Ubuntu 22.04
Android Platform 37.0
Build Tools 37.0.0
NDK 28.2.13676358
Gradle 9.4.1
Node.js 22.14
Yarn (version non fixée)
JDK 17.

docker build .

> time to build on Dell laptop: Intel i7 11800H with 32GB RAM, Docker Desktop:  335s
> image size: 6.5GB

> basé sur debian bookworm-slim: 285s
> image size: 6.64 GB rapportés (4.77 GB de layers) - blobs compressés

APK résultant: 
~/repos/AppsMobiles2/react-native-docker-android/examples/android-hello-world/android/app/build/outputs/apk/release/app-release.apk

---

Optimisation:

Build arm64-v8a et x86-64

Avec seulement un changement au titre dans App.tsx: 2m28s

-v ~/.gradle/caches:/root/.gradle/caches: 2m18s

Avec un volume Docker pour le home Gradle + --configuration-cache: 19s !!
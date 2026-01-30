@Library(['dockerHelpers']) _

// Script-level variable to store image matrix
def imageMatrix = null

pipeline {
	agent none

	environment {
		REGISTRY = "rg.fr-par.scw.cloud/testing-images"

		// Jenkins node labels
		AMD64_LABEL = "amd64 && docker"     // your Scaleway builder/agent
		ARM64_LABEL = "arm64 && docker"     // your Raspberry Pi agent

		// Scaleway registry hostname for login
		REGISTRY_HOST = "rg.fr-par.scw.cloud"
	}

	stages {
		stage('Build + Push per-arch (parallel)') {
			steps {
				script {
					imageMatrix = [
						[
							name: 'node',
							versions: [
								[dir: 'node/24', tag: '24'],
								[dir: 'node/25', tag: '25'],
								[dir: 'node/lts', tags: ['lts', 'latest']]
							]
						],
						[
							name: 'php',
							versions: [
								[dir: 'php/8_4', tag: '8.4'],
								[dir: 'php/8_5', tags: ['8.5', '8', 'latest']]
							]
						]
					]

					def parallelBuilds = [:]

					parallelBuilds["amd64"] = {
						node(env.AMD64_LABEL) {
							withCredentials([string(credentialsId: 'scaleway_secret_key', variable: 'SECRET')]) {
								dockerRegistryLogin(registryUrl: env.REGISTRY_HOST, username: 'nologin', password: SECRET)

								imageMatrix.each { imageConfig ->
									def imageName = imageConfig.name
									imageConfig.versions.each { v ->
										def baseTag = v.tag ?: (v.tags?.size() ? v.tags[0] : 'temp')
										def archTag = "${baseTag}-amd64"

										dockerBuildImage(
											registry: env.REGISTRY,
											image: imageName,
											contextDir: v.dir,
											tag: archTag,
											platform: "linux/amd64",
											push: true
										)
									}
								}

								dockerRegistryLogout(env.REGISTRY_HOST)
							}
						}
					}

					parallelBuilds["arm64"] = {
						node(env.ARM64_LABEL) {
							withCredentials([string(credentialsId: 'scaleway_secret_key', variable: 'SECRET')]) {
								dockerRegistryLogin(registryUrl: env.REGISTRY_HOST, username: 'nologin', password: SECRET)

								imageMatrix.each { imageConfig ->
									def imageName = imageConfig.name
									imageConfig.versions.each { v ->
										def baseTag = v.tag ?: (v.tags?.size() ? v.tags[0] : 'temp')
										def archTag = "${baseTag}-arm64"

										dockerBuildImage(
											registry: env.REGISTRY,
											image: imageName,
											contextDir: v.dir,
											tag: archTag,
											platform: "linux/arm64",
											push: true
										)
									}
								}

								dockerRegistryLogout(env.REGISTRY_HOST)
							}
						}
					}

					parallel parallelBuilds
				}
			}
		}

		stage('Create multi-arch manifests') {
			agent { label "${AMD64_LABEL}" }
			steps {
				script {
					withCredentials([string(credentialsId: 'scaleway_secret_key', variable: 'SECRET')]) {
						dockerRegistryLogin(registryUrl: env.REGISTRY_HOST, username: 'nologin', password: SECRET)

						def mergeList = []

						imageMatrix.each { imageConfig ->
							def imageName = imageConfig.name
							imageConfig.versions.each { v ->
								def baseTag = v.tag ?: (v.tags?.size() ? v.tags[0] : 'temp')

								mergeList << [
									name: imageName,
									baseTag: baseTag,
									archTags: [
										amd64: "${baseTag}-amd64",
										arm64: "${baseTag}-arm64"
									],
									extraTags: v.tags ?: []
								]
							}
						}

						dockerMergeManifests(registry: env.REGISTRY, images: mergeList)

						dockerRegistryLogout(env.REGISTRY_HOST)
					}
				}
			}
		}
	}

	post {
		always { echo 'Pipeline completed' }
		success { echo 'All images built + pushed + multi-arch manifests created!' }
		failure { echo 'Pipeline failed. Check the logs for details.' }
	}
}

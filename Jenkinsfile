@Library(['dockerHelpers']) _

// Script-level variable to store image matrix
def imageMatrix = null

def archs = null

pipeline {
	agent none

	environment {
		REGISTRY = "rg.fr-par.scw.cloud/testing-images"

		// Jenkins node labels
		AMD64_LABEL = "amd64"     // your Scaleway builder/agent
		ARM64_LABEL = "arm64"     // your Raspberry Pi agent

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

					archs = [
						amd64: [
							label: env.AMD64_LABEL,
							platform: "linux/amd64"
						],
						arm64: [
							label: env.ARM64_LABEL,
							platform: "linux/arm64"
						]
					]

					def parallelBuilds = [:]

					archs.each { arch, config ->
						parallelBuilds[arch] = {
							node(config.label) {
								checkout scm

								withCredentials([string(credentialsId: 'scaleway_secret_key', variable: 'SECRET')]) {
									dockerRegistryLogin(registryUrl: env.REGISTRY_HOST, username: 'nologin', password: SECRET)

									def buildStages = [:]

									imageMatrix.each { imageConfig ->
										buildStages["Building ${imageConfig.name} for ${arch}"] = {
											steps {
												script {
													def imageName = imageConfig.name
													imageConfig.versions.each { v ->
														def baseTag = v.tag ?: (v.tags?.size() ? v.tags[0] : 'temp')
														def archTag = "${baseTag}-${arch}"

														dockerBuildImage(
															registry: env.REGISTRY,
															image: imageName,
															contextDir: v.dir,
															tag: archTag,
															platform: config.platform,
															push: true
														)
													}
												}
											}
										}
									}

									parallel buildStages

									dockerRegistryLogout(env.REGISTRY_HOST)
								}
							}
						}
					}

					parallel parallelBuilds
				}
			}
		}

		stage('Create multi-arch manifests') {
			agent any
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
		always {
			echo 'Pipeline completed'
		}
		success {
			echo 'All images built + pushed + multi-arch manifests created!'
		}
		failure {
			echo 'Pipeline failed. Check the logs for details.'
		}
	}
}
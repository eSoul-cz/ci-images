@Library(['dockerHelpers']) _

// Script-level variable to store image matrix
def imageMatrix = null

def archs = null

pipeline {
	agent none

	environment {
		REGISTRY = "rg.fr-par.scw.cloud/testing-images"
		STARTERS_REGISTRY = "rg.fr-par.scw.cloud/esoul-starters"

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
						],
						[
							name: 'php-fpm',
							registry: env.STARTERS_REGISTRY,
							registryHost: env.REGISTRY_HOST,
							versions: [
								[
									dir: 'php/base',
									tags: ['8.5.3', '8.5', '8', 'latest'],
									// Built sequentially so each stage reuses the previous layer cache
									stages: [
										[target: 'base',            imageSuffix: ''],
										[target: 'laravel-minimal', imageSuffix: '-laravel-minimal'],
										[target: 'laravel',         imageSuffix: '-laravel']
									]
								],
								[
									dir: 'php/base',
									tag: '8.4',
									buildArgs: [VERSION: '8.4'],
									stages: [
										[target: 'base',            imageSuffix: ''],
										[target: 'laravel-minimal', imageSuffix: '-laravel-minimal'],
										[target: 'laravel',         imageSuffix: '-laravel']
									]
								]
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
										def imageRegistry = imageConfig.registry ?: env.REGISTRY
										buildStages["Building ${imageRegistry}/${imageConfig.name} for ${arch}"] = {
											def imageName = imageConfig.name
											imageConfig.versions.each { v ->
												def baseTag = v.tag ?: (v.tags?.size() ? v.tags[0] : 'temp')

												if (v.stages) {
													// Build each Dockerfile stage sequentially so later stages
													// can reuse the Docker layer cache populated by earlier ones.
													v.stages.each { s ->
														def archTag = "${baseTag}-${arch}"
														def buildParams = [
															registry: imageRegistry,
															image: "${imageName}${s.imageSuffix}",
															contextDir: v.dir,
															tag: archTag,
															platform: config.platform,
															push: true,
															extraFlags: "--target ${s.target}"
														]
														if (v.buildArgs) buildParams.buildArgs = v.buildArgs
														dockerBuildImage(buildParams)
													}
												} else {
													def archTag = "${baseTag}-${arch}"
													def buildParams = [
														registry: imageRegistry,
														image: imageName,
														contextDir: v.dir,
														tag: archTag,
														platform: config.platform,
														push: true
													]
													if (v.buildArgs) buildParams.buildArgs = v.buildArgs
													if (v.target) buildParams.extraFlags = "--target ${v.target}"
													dockerBuildImage(buildParams)
												}
											}
										}
									}

									parallel buildStages
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

						def mergeListByRegistry = [:]

						imageMatrix.each { imageConfig ->
							def imageName = imageConfig.name
							def imageRegistry = imageConfig.registry ?: env.REGISTRY
							mergeListByRegistry[imageRegistry] = mergeListByRegistry[imageRegistry] ?: []
							imageConfig.versions.each { v ->
								def baseTag = v.tag ?: (v.tags?.size() ? v.tags[0] : 'temp')

								if (v.stages) {
									v.stages.each { s ->
										mergeListByRegistry[imageRegistry] << [
											name: "${imageName}${s.imageSuffix}",
											baseTag: baseTag,
											archTags: [
												amd64: "${baseTag}-amd64",
												arm64: "${baseTag}-arm64"
											],
											extraTags: v.tags ?: []
										]
									}
								} else {
									mergeListByRegistry[imageRegistry] << [
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
						}

						mergeListByRegistry.each { registry, mergeList ->
							dockerMergeManifests(registry: registry, images: mergeList)
						}
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
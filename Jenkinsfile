@Library(['dockerHelpers']) _

// Script-level variable to store image matrix
def imageMatrix = null

def archs = null

// One entry per published multi-arch image: [registry, name, baseTag, extraTags].
def publishedImages(matrix, defaultRegistry) {
	def images = []
	matrix.each { imageConfig ->
		def registry = imageConfig.registry ?: defaultRegistry
		imageConfig.versions.each { v ->
			def baseTag = v.tag ?: (v.tags?.size() ? v.tags[0] : 'temp')
			def suffixes = v.stages ? v.stages.collect { it.imageSuffix } : ['']
			suffixes.each { suffix ->
				images << [
					registry: registry,
					name: "${imageConfig.name}${suffix}",
					baseTag: baseTag,
					extraTags: v.tags ?: []
				]
			}
		}
	}
	return images
}

pipeline {
	agent none

	triggers {
		// Jenkins evaluates this in the controller timezone.
		cron('H 1 * * *')
	}

	options {
		disableConcurrentBuilds()
		overrideIndexTriggers(false)
	}

	parameters {
		booleanParam(
			name: 'SECURITY_SCAN',
			defaultValue: true,
			description: 'Run the Trivy vulnerability report on published images. Findings mark only the scan stage UNSTABLE.'
		)
		booleanParam(
			name: 'RENOVATE',
			defaultValue: true,
			description: 'Run Renovate on master to open version-update PRs (see renovate.json5). Failures mark only the Renovate stage UNSTABLE.'
		)
	}

	environment {
		REGISTRY = "rg.fr-par.scw.cloud/testing-images"
		STARTERS_REGISTRY = "rg.fr-par.scw.cloud/esoul-starters"

		// Jenkins node labels
		AMD64_LABEL = "amd64"     // your Scaleway builder/agent
		ARM64_LABEL = "arm64"     // your Raspberry Pi agent

		// Scaleway registry hostname for login
		REGISTRY_HOST = "rg.fr-par.scw.cloud"

		// Keep native Docker/PHP image builds from saturating shared Jenkins hosts.
		CI_IMAGES_PARALLEL_BUILDS = "false"
		PHP_BUILD_PROCESSOR_COUNT = "2"

		// Soft Trivy report (scripts/trivy-scan.sh forwards every TRIVY_* variable).
		TRIVY_SEVERITY = "HIGH,CRITICAL"
		TRIVY_IGNORE_UNFIXED = "true"

		// Self-hosted Renovate; renovate.json5 bumps this version too.
		RENOVATE_IMAGE = "renovate/renovate:44.133.0"
	}

	stages {
		// Runs first so update PRs still open when an image build breaks.
		stage('Renovate') {
			when {
				expression { params.RENOVATE != false }
				expression { !env.BRANCH_NAME || env.BRANCH_NAME == 'master' }
				expression {
					def timerCauses = currentBuild.getBuildCauses('hudson.triggers.TimerTrigger$TimerTriggerCause')
					def userCauses = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')
					return !timerCauses.isEmpty() || !userCauses.isEmpty()
				}
			}
			steps {
				// Soft step: Renovate problems must never block the nightly image build.
				catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
					script {
						node(env.AMD64_LABEL) {
							// GitHub App credential: the password is a short-lived installation token.
							withCredentials([usernamePassword(credentialsId: 'renovate', usernameVariable: 'RENOVATE_APP_ID', passwordVariable: 'RENOVATE_TOKEN')]) {
								sh '''
									docker run --rm \
										-e RENOVATE_TOKEN \
										-e RENOVATE_PLATFORM=github \
										-e RENOVATE_REPOSITORIES=eSoul-cz/ci-images \
										-e RENOVATE_ONBOARDING=false \
										-e RENOVATE_REQUIRE_CONFIG=required \
										-e LOG_LEVEL=info \
										"$RENOVATE_IMAGE"
								'''
							}
						}
					}
				}
			}
		}

		stage('Build + Push per-arch (parallel)') {
			when {
				beforeAgent true
				expression {
					def timerCauses = currentBuild.getBuildCauses('hudson.triggers.TimerTrigger$TimerTriggerCause')
					def userCauses = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')
					return (!timerCauses.isEmpty() && (!env.BRANCH_NAME || env.BRANCH_NAME == 'master')) || !userCauses.isEmpty()
				}
			}
			steps {
				script {
					imageMatrix = [
						[
							name: 'node',
							versions: [
								[dir: 'node/24', tag: '24'],
								[dir: 'node/26', tag: '26'],
								[dir: 'node/lts', tags: ['lts', 'latest']]
							]
						],
						[
							name: 'playwright',
							versions: [
								[dir: 'playwright', tag: 'latest'],
							]
						],
						[
							name: 'php',
							versions: [
								[
									dir: 'php/8_4',
									tags: ['8.4.26', '8.4'],
									buildArgs: [VERSION: '8.4.26'],
									stages: [
										[
											target: 'base',
											imageSuffix: ''
										],
										[
											target: 'node',
											imageSuffix: '-node'
										]
									]
								],
								[
									dir: 'php/8_5',
									tags: ['8.5.11', '8.5', '8', 'latest'],
									buildArgs: [VERSION: '8.5.11'],
									stages: [
										[
											target: 'base',
											imageSuffix: ''
										],
										[
											target: 'node',
											imageSuffix: '-node'
										]
									],
								]
							]
						],
						[
							name: 'php-cli',
							registry: env.STARTERS_REGISTRY,
							registryHost: env.REGISTRY_HOST,
							versions: [
								[
									dir: 'php/roadrunner',
									tags: ['8.5.11', '8.5', '8', 'latest'],
									buildArgs: [VERSION: '8.5.11'],
									stages: [
										[target: 'runtime',    imageSuffix: ''],
										[target: 'roadrunner', imageSuffix: '-roadrunner']
									]
								]
							]
						],
						[
							name: 'php-fpm',
							registry: env.STARTERS_REGISTRY,
							registryHost: env.REGISTRY_HOST,
							versions: [
								[
									dir: 'php/base',
									tags: ['8.5.11', '8.5', '8', 'latest'],
									buildArgs: [VERSION: '8.5.11'],
									// Built sequentially so each stage reuses the previous layer cache
									stages: [
										[target: 'base',            imageSuffix: ''],
										[target: 'laravel-minimal', imageSuffix: '-laravel-minimal'],
										[target: 'laravel',         imageSuffix: '-laravel']
									]
								],
								[
									dir: 'php/base',
									tags: ['8.4.26', '8.4'],
									buildArgs: [VERSION: '8.4.26'],
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
													v.stages.each { s ->
														def archTag = "${baseTag}-${arch}"
														def cacheTag = "buildcache-${baseTag}-${s.target}-${arch}"
														def buildParams = [
															registry: imageRegistry,
															image: "${imageName}${s.imageSuffix}",
															contextDir: v.dir,
															tag: archTag,
															platform: config.platform,
															push: true,
															cacheRef: "${imageRegistry}/${imageName}${s.imageSuffix}:${cacheTag}",
															extraFlags: "--target ${s.target}"
														]
														if (imageName.startsWith('php')) buildParams.buildArgs = [IPE_PROCESSOR_COUNT: env.PHP_BUILD_PROCESSOR_COUNT]
														if (v.buildArgs) buildParams.buildArgs = (buildParams.buildArgs ?: [:]) + v.buildArgs
														dockerBuildImage(buildParams)
													}
												} else {
													def archTag = "${baseTag}-${arch}"
													def cacheTag = "buildcache-${baseTag}-${arch}"
													def buildParams = [
														registry: imageRegistry,
														image: imageName,
														contextDir: v.dir,
														tag: archTag,
														platform: config.platform,
														push: true,
														cacheRef: "${imageRegistry}/${imageName}:${cacheTag}"
													]
													if (v.buildArgs) buildParams.buildArgs = v.buildArgs
													if (v.target) buildParams.extraFlags = "--target ${v.target}"
													dockerBuildImage(buildParams)
												}
											}
										}
									}

									// Detect if the agent label contains 'lowmem' for sequential build (any arch)
									def nodeLabels = env.NODE_LABELS ?: ''
									def isLowmem = nodeLabels.split().collect { it.toLowerCase() }.contains('lowmem')
									def runParallelBuilds = env.CI_IMAGES_PARALLEL_BUILDS?.toBoolean()

									if (isLowmem || !runParallelBuilds) {
										// Run builds sequentially on lowmem agents or when global image-build throttling is enabled.
										buildStages.each { name, stageClosure ->
											echo "[${arch.toUpperCase()}] Running: ${name} (sequential)"
											stageClosure()
										}
									} else {
										// Run builds in parallel on non-lowmem agents
										parallel buildStages
									}
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
			when {
				beforeAgent true
				expression {
					def timerCauses = currentBuild.getBuildCauses('hudson.triggers.TimerTrigger$TimerTriggerCause')
					def userCauses = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')
					return (!timerCauses.isEmpty() && (!env.BRANCH_NAME || env.BRANCH_NAME == 'master')) || !userCauses.isEmpty()
				}
			}
			steps {
				script {
					withCredentials([string(credentialsId: 'scaleway_secret_key', variable: 'SECRET')]) {
						dockerRegistryLogin(registryUrl: env.REGISTRY_HOST, username: 'nologin', password: SECRET)

						def mergeListByRegistry = [:]

						publishedImages(imageMatrix, env.REGISTRY).each { image ->
							mergeListByRegistry[image.registry] = mergeListByRegistry[image.registry] ?: []
							mergeListByRegistry[image.registry] << [
								name: image.name,
								baseTag: image.baseTag,
								archTags: [
									amd64: "${image.baseTag}-amd64",
									arm64: "${image.baseTag}-arm64"
								],
								extraTags: image.extraTags
							]
						}

						mergeListByRegistry.each { registry, mergeList ->
							dockerMergeManifests(registry: registry, images: mergeList)
						}
					}
				}
			}
		}

		stage('Security scan (Trivy)') {
			agent any
			when {
				beforeAgent true
				allOf {
					expression { params.SECURITY_SCAN != false }
					expression {
						def timerCauses = currentBuild.getBuildCauses('hudson.triggers.TimerTrigger$TimerTriggerCause')
						def userCauses = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')
						return (!timerCauses.isEmpty() && (!env.BRANCH_NAME || env.BRANCH_NAME == 'master')) || !userCauses.isEmpty()
					}
				}
			}
			steps {
				// Soft report: nothing in this stage may fail the build or block publishing.
				catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
					script {
						def reportDir = 'build/trivy'
						def refs = publishedImages(imageMatrix, env.REGISTRY).collect { image ->
							"'${image.registry}/${image.name}:${image.baseTag}'"
						}
						def status = 0

						sh "rm -rf '${reportDir}'"
						withCredentials([string(credentialsId: 'scaleway_secret_key', variable: 'TRIVY_PASSWORD')]) {
							withEnv(['TRIVY_USERNAME=nologin', 'TRIVY_IMAGE_SRC=remote']) {
								status = sh(
									returnStatus: true,
									script: "./scripts/trivy-scan.sh -o '${reportDir}' ${refs.join(' ')}"
								)
							}
						}
						archiveArtifacts(artifacts: "${reportDir}/*", allowEmptyArchive: true, fingerprint: false)

						if (status == 10) {
							error("Trivy found ${env.TRIVY_SEVERITY} vulnerabilities with available fixes; see archived build/trivy reports.")
						} else if (status != 0) {
							error("Trivy scan did not complete for every image (exit ${status}); see the log above.")
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

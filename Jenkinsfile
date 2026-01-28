pipeline {
	agent any

	environment {
		REGISTRY = "rg.fr-par.scw.cloud/testing-images"

		// Build architectures
		BUILD_ARCHS = 'linux/amd64,linux/arm64'
	}

	stages {
		stage('Setup Buildx') {
			steps {
				script {
					// Create and use buildx builder for multi-platform builds
					sh '''
						# Create buildx builder if it doesn't exist
						docker buildx create --name multiarch --driver docker-container --use || docker buildx use multiarch

						# Bootstrap the builder (pulls required images)
						docker buildx inspect --bootstrap
					'''
				}
			}
		}

		stage('Docker Login') {
			steps {
				script {
					withCredentials([string(credentialsId: 'scaleway_secret_key', variable: 'SECRET')]) {
						sh '''
							echo "$SECRET" | docker login rg.fr-par.scw.cloud/testing-images -u nologin --password-stdin
						'''
					}
				}
			}
		}

		stage('Build Images') {
			steps {
				script {
					// Define image configurations grouped by name
					// Each version: dir (required), tag (optional), tags (array of additional tags)
					env.BUILD_IMAGES = true
					def images = [
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
					def buildStages = [:]

					// Store image names for push stage
					env.IMAGE_NAMES = images.collect {
						it.name
					}.join(',')

					// Build each image's versions in parallel
					images.each { imageConfig ->
						def imageName = imageConfig.name
						def versions = imageConfig.versions

						versions.each { version ->
							def displayName = version.tag ?: (version.tags?.size() > 0 ? "${imageName}:${version.tags[0]}" : "${imageName} (no tags)")

							// Create unique key for parallel map
							buildStages[displayName] = {
								echo "Building ${displayName} from ${version.dir}"

								def buildTag = version.tag ?: (version.tags?.size() > 0 ? version.tags[0] : 'temp')
								def primaryImage = "${env.REGISTRY}/${imageName}:${buildTag}"

								sh "docker buildx build --platform ${env.BUILD_ARCHS} --load -t ${primaryImage} ${version.dir}"

								if (version.tag && buildTag != version.tag) {
									def taggedImage = "${env.REGISTRY}/${imageName}:${version.tag}"
									sh "docker tag ${primaryImage} ${taggedImage}"
								}

								if (version.tags && version.tags.size() > 0) {
									version.tags.each { tag ->
										if (tag != buildTag) {
											def additionalTag = "${env.REGISTRY}/${imageName}:${tag}"
											sh "docker tag ${primaryImage} ${additionalTag}"
										}
									}
								}

								echo "Successfully built ${displayName}"
							}
						}
					}

					parallel buildStages
				}
			}
		}

		stage('Push Images') {
			steps {
				script {
					// Get image names from build stage
					def imageNames = env.IMAGE_NAMES.split(',')

					// Push each image (all versions/tags together)
					imageNames.each { imageName ->
						stage("Push ${imageName}") {
							echo "Pushing all tags for ${imageName}"

							// Push all tags for this image in a single command
							sh "docker push --all-tags ${env.REGISTRY}/${imageName}"

							echo "Successfully pushed all tags for ${imageName}"
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
			echo 'All images built and pushed successfully!'
		}
		failure {
			echo 'Pipeline failed. Check the logs for details.'
		}
	}
}
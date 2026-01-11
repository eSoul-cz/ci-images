pipeline {
	agent any

	environment {
		REGISTRY = "rg.fr-par.scw.cloud/testing-images"
		// Define image configurations grouped by name
		// Each version: dir (required), tag (optional), tags (array of additional tags)
		IMAGES = [
			[
				name: 'node',
				versions: [
					[dir: 'node/25', tags: ['25', 'latest']]
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
	}

	stages {
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
					// Build each image
					IMAGES.each { imageConfig ->
						imageConfig.versions.each { version ->
							def displayName = version.tag ? "${imageConfig.name}:${version.tag}" : "${imageConfig.name} (tags only)"
							stage("Build ${displayName}") {
								echo "Building ${displayName} from ${version.dir}"

								// Determine the primary build tag
								def buildTag = version.tag ?: (version.tags?.size() > 0 ? version.tags[0] : 'temp')
								def primaryImage = "${env.REGISTRY}/${imageConfig.name}:${buildTag}"

								// Build the Docker image
								sh "docker build -t ${primaryImage} ${version.dir}"

								// If tag exists and is different from build tag, tag it
								if (version.tag && buildTag != version.tag) {
									def taggedImage = "${env.REGISTRY}/${imageConfig.name}:${version.tag}"
									sh "docker tag ${primaryImage} ${taggedImage}"
								}

								// Tag with additional tags
								if (version.tags && version.tags.size() > 0) {
									version.tags.each { tag ->
										// Skip if this was already the build tag
										if (tag != buildTag) {
											def additionalTag = "${env.REGISTRY}/${imageConfig.name}:${tag}"
											sh "docker tag ${primaryImage} ${additionalTag}"
										}
									}
								}

								echo "Successfully built ${displayName}"
							}
						}
					}
				}
			}
		}

		stage('Push Images') {
			steps {
				script {
					// Push each image (all versions/tags together)
					IMAGES.each { imageConfig ->
						stage("Push ${imageConfig.name}") {
							echo "Pushing all tags for ${imageConfig.name}"

							// Push all tags for this image in a single command
							sh "docker push --all-tags ${env.REGISTRY}/${imageConfig.name}"

							echo "Successfully pushed all tags for ${imageConfig.name}"
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
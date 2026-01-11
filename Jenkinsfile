pipeline {
	agent any

	environment {
		REGISTRY = "rg.fr-par.scw.cloud/testing-images"
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

		stage('Build and Push Images') {
			steps {
				script {
					// Define image configurations
					def images = [
						[dir: 'node/25', name: 'node', tag: '25'],
						[dir: 'php/8_4', name: 'php', tag: '8.4'],
						[dir: 'php/8_5', name: 'php', tag: '8.5']
					]

					// Build and push each image
					images.each { image ->
						stage("Build ${image.name}:${image.tag}") {
							echo "Building ${image.name}:${image.tag} from ${image.dir}"

							def imageName = "${env.REGISTRY}/${image.name}:${image.tag}"
							def latestTag = "${env.REGISTRY}/${image.name}:latest"

							// Build the Docker image
							sh """
								docker build -t ${imageName} ${image.dir}
							"""

							// Tag as latest if it's the highest version
							if ((image.name == 'node' && image.tag == '25') ||
							    (image.name == 'php' && image.tag == '8.5')) {
								sh """
									docker tag ${imageName} ${latestTag}
								"""
							}

							// Push the image
							sh """
								docker push ${imageName}
							"""

							// Push latest tag if applicable
							if ((image.name == 'node' && image.tag == '25') ||
							    (image.name == 'php' && image.tag == '8.5')) {
								sh """
									docker push ${latestTag}
								"""
							}

							echo "Successfully built and pushed ${imageName}"
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
pipeline {
  agent any

  stages {
    stage('Create test bootscript') {
      steps {
        script {
          json_message = sh(
            script: './request_json.sh ${BUILD_BRANCH} ${BUILD_NUMBER} ${ARCH}',
            returnStdout: true
          )
        }
        echo "$json_message"
        script {
          bootscript = input(
            message: "${json_message}",
            parameters: [string(name: 'bootscript_id', description: 'ID of the created bootscript')]
          )
        }
        echo "received bootscript ID: ${bootscript}"
      }
    }
  }
}


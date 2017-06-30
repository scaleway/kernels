pipeline {
  agent {
    label 'master||worker'
  }

  parameters {
    string(name: 'buildBranch', description: 'Kernel branch to test and release')
    string(name: 'buildNumber', description: 'Kernel-build run number to get artifacts from')
    choice(name: 'arch', choices: 'arm\narm64\nx86_64', description: 'Arch to test and deploy kernel on')
    booleanParam(name: 'noTest', defaultValue: false, description: 'Don\'t test the kernel')
    string(name: 'testServerType', defaultValue: '', description: 'Scaleway server type to test the kernel on')
    string(name: 'testImage', defaultValue: '', description: 'Scaleway image to test the kernel on')
    booleanParam(name: 'noRelease', defaultValue: false, description: 'Don\'t release the kernel')
  }

  stages {
    stage('Test the kernel') {
      when {
        expression { params.noTest == false }
      }
      steps {
        script {
          json_message = sh(
            script: "./request_json.sh ${params.buildBranch} ${params.buildNumber} ${params.arch} test",
            returnStdout: true
          )
          bootscript = input(
            message: "${json_message}",
            parameters: [string(name: 'bootscript_id', description: 'ID of the created bootscript')]
          )
        }
        echo "Created test bootscript: ${bootscript}"
        script {
          withCredentials([usernamePassword(credentialsId: 'scw-test-orga-token', usernameVariable: 'SCW_ORGANIZATION', passwordVariable: 'SCW_TOKEN')]) {
            server = sh(
              script: "./test_kernel.sh start ${bootscript} ${params.testServerType} ${params.testImage}",
              returnStdout: true
            ).trim()
          }
        }
        input message: "Created server ${server}, please test it. Confirm that the kernel stable ?", ok: 'Confirm'
      }
      post {
        always {
          sh "./test_kernel.sh stop ${server}"
        }
      }
    }
    stage('Release the kernel') {
      when {
        expression { params.noRelease == false }
      }
      steps {
        script {
          json_message = sh(
            script: "./request_json.sh ${params.buildBranch} ${params.buildNumber} ${params.arch} release",
            returnStdout: true
          )
          bootscript = input(
            message: "${json_message}",
            parameters: [string(name: 'bootscript_id', description: 'ID of the created bootscript')]
          )
        }
        echo "Created release bootscript: ${bootscript}"
        dir("release") {
          writeFile file: "bootscript", text: "${bootscript}"
          archive "bootscript"
          deleteDir()
        }
      }
    }
  }
}


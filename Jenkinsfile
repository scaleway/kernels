def jenkins_url = new JenkinsLocationConfiguration().getUrl()
def kernel_build = new groovy.json.JsonSlurperClassic().parseText(new URL("${jenkins_url}/job/kernel-build/api/json").getText());
def branches = [:]
def branch_names = []
def branch_name = ""
for (Map branch : kernel_build['jobs']) {
  branch_name = URLDecoder.decode(branch['name'], "UTF-8")
  branches.put(branch_name, branch['url'])
  branch_names.add(branch_name)
}
def branches_choice = branch_names.join('\n')

pipeline {
  agent {
    label 'master'
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '15'))
  }

  parameters {
    choice(name: 'buildBranch', choices: branches_choice, description: 'Kernel branch to test and release')
    choice(name: 'arch', choices: 'arm\narm64\nx86_64', description: 'Arch to test and deploy kernel on')
    booleanParam(name: 'noTest', defaultValue: false, description: 'Don\'t test the kernel')
    booleanParam(name: 'needsAdminApproval', defaultValue: false, description: 'Wait for admin approval after testing')
    booleanParam(name: 'noRelease', defaultValue: false, description: 'Don\'t release the kernel')
  }

  stages {
    stage('Prepare environment') {
      steps {
        script {
          env.BRANCH_URL_ENC = URLEncoder.encode(URLEncoder.encode(params.buildBranch, "UTF-8"), "UTF-8")
        }
      }
    }
    stage('Test the kernel') {
      when {
        expression { params.noTest == false }
      }
      steps {
        script {
          last_success = new groovy.json.JsonSlurperClassic().parseText(new URL("${jenkins_url}/job/kernel-build/job/${env.BRANCH_URL_ENC}/lastSuccessfulBuild/api/json").getText())
          last_success_number = last_success['id']
          bootscript_request = groovy.json.JsonOutput.toJson([
            type: "bootscript",
            options: [
              test: true
            ],
            data: [
              url: "${jenkins_url}job/kernel-build/job/${env.BRANCH_URL_ENC}/${last_success_number}/artifact/${params.arch}/release"
            ]
          ])
          bootscript = input(
            message: bootscript_request,
            parameters: [string(name: 'bootscript_id', description: 'ID of the created bootscript')]
          )
        }
        echo "Created test bootscript: ${bootscript}"
        withCredentials([usernamePassword(credentialsId: 'scw-test-orga-token', usernameVariable: 'SCW_ORGANIZATION', passwordVariable: 'SCW_TOKEN')]) {
          sh "./test_kernel.sh start ${env.arch} ${params.buildBranch} ${bootscript} servers_list"
        }
        script {
          servers_info = readFile('servers_list').trim().split('\n')
          servers_booted = ["The following servers have been booted and passed basic checks:"]
          servers_booted.add(["TYPE".padRight(10), "NAME".padRight(50), "ID".padRight(36)].join("| "))
          servers_booted.add([''.padRight(10, '-'), ''.padRight(50, '-'), ''.padRight(36, '-')].join("|-"))
          for (String server_info : servers_info) {
            info = server_info.split(' ')
            servers_booted.add([info[0].padRight(10), info[1].padRight(50), info[2].padRight(36)].join("| "))
          }
          echo servers_booted.join('\n')
          if (params.needsAdminApproval) {
            input message: "You can run some manual checks on the booted server(s). Confirm that the kernel stable ?", ok: 'Confirm'
            emailext(
              to: "jtamba@online.net",
              subject: "Kernel test #${env.BUILD_NUMBER} needs admin approval",
              body: """<p>A new version of kernel ${env.buildBranch} is being tested.\n ${servers_booted}\n You can ssh into the test server(s) and do some manual checks.</p>
              <p>If the kernel is fit for release, you can <a href="${env.JENKINS_URL}/blue/organizations/jenkins/kernel-release/detail/kernel-release/${env.BUILD_NUMBER}"> go to the pipeline</a> to confirm the build or otherwise abort it.</p>
              """
            )
          }
        }
      }
      post {
        always {
          withCredentials([usernamePassword(credentialsId: 'scw-test-orga-token', usernameVariable: 'SCW_ORGANIZATION', passwordVariable: 'SCW_TOKEN')]) {
            sh "./test_kernel.sh stop servers_list"
          }
        }
      }
    }
    stage('Release the kernel') {
      when {
        expression { params.noRelease == false }
      }
      steps {
        script {
          bootscript_request = groovy.json.JsonOutput.toJson([
            type: "bootscript",
            options: [
              test: false
            ],
            data: [
              url: "${jenkins_url}job/kernel-build/job/${env.BRANCH_URL_ENC}/lastSuccessfulBuild/artifact/${params.arch}/release"
            ]
          ])
          bootscript = input(
            message: bootscript_request,
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
  post {
    success {
      script {
        if (params.noRelease == "false") {
          bootscript = readFile "release/bootscript"
          subject = "Kernel test ${env.buildBranch} #${env.BUILD_NUMBER} succeeded, kernel has been released"
          body = """<p>Created bootscript for new ${env.buildBranch} kernel on ${env.arch}: ${bootscript}.</p><p>See full log <a href="${env.JENKINS_URL}/blue/organizations/jenkins/kernel-release/detail/kernel-release/${env.BUILD_NUMBER}">here</a></p>
            """

        } else {
          subject = "Kernel test ${env.buildBranch} #${env.BUILD_NUMBER} succeeded"
          body = """<p>See full log <a href="${env.JENKINS_URL}/blue/organizations/jenkins/kernel-release/detail/kernel-release/${env.BUILD_NUMBER}">here</a></p>"""
        }
      }
      emailext(
        to: "jtamba@online.net",
        subject: subject,
        body: body
      )
    }
    failure {
      emailext(
        to: "jtamba@online.net",
        subject: "Kernel test ${env.buildBranch} #${env.BUILD_NUMBER} failed",
        body: """<p>See full log <a href="${env.JENKINS_URL}/blue/organizations/jenkins/kernel-release/detail/kernel-release/${env.BUILD_NUMBER}">here</a></p>"""
      )
    }
    always {
      deleteDir()
    }
  }
}

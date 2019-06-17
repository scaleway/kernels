pipeline {
  agent {
    label 'x86_64&&distcc'
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '1'))
    timeout(time: 4, unit: 'HOURS')
  }

  triggers {
    pollSCM("H H * * *")
  }

  environment {
    USE_DISTCC="y"
    CONCURRENCY=sh(script: 'expr "(" $(nproc) + $(tail -n +2 ~/.distcc/hosts | wc -l) "*" 4 ")" "*" 2', returnStdout: true).trim()
  }

  stages {
    stage('Checkout last kernel version') {
      steps {
        dir("kernel") {
          checkout([
            $class: 'GitSCM',
            poll: true,
            branches: [[name: 'linux-4.9.y']],
            extensions: [
              [$class: 'CheckoutOption', timeout: 30],
              [$class: 'CloneOption', timeout: 60],
              [$class: 'CleanBeforeCheckout']
            ],
            userRemoteConfigs: [[url: "git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git" ]]
          ])
          script {
            env.kernelVersion = sh(script: 'make kernelversion', returnStdout: true).trim()
          }
        }
        echo "Building kernel version: ${env.kernelVersion}"
      }
    }
    stage('Compute revision number') {
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: 'scw-test-orga-token', usernameVariable: 'SCW_ORGANIZATION', passwordVariable: 'SCW_TOKEN')]) {
            env.kernelRevision = sh(script: "curl -G -s https://cp-par1.scaleway.com/bootscripts -d title='mainline ${env.kernelVersion} rev' -H 'x-auth-token: ${SCW_TOKEN}' | jq -r '[ .bootscripts[].title | scan(\"rev[0-9]+\")[3:] | tonumber ] | max // 0 | . + 1'", returnStdout: true).trim()
          }
        }
        echo "Kernel build revision: ${env.kernelRevision}"
      }
    }
    stage('Compile kernel: arm') {
      steps {
        dir("kernel") {
          sh 'git clean -ffdx && git reset --hard'
        }
        dir("arm") {
          dir("release") {
            deleteDir()
          }
          dir("build") {
            deleteDir()
          }
          sh "make -C '${WORKSPACE}' linux TARGET_ARCH=arm REVISION=${env.kernelRevision} KERNEL_SRC_DIR='${WORKSPACE}/kernel' BUILD_DIR='${WORKSPACE}/arm/build' RELEASE_DIR='${WORKSPACE}/arm/release'"
        }
      }
    }
    stage('Compile kernel: x86_64') {
      steps {
        dir("kernel") {
          sh 'git clean -ffdx && git reset --hard'
        }
        dir("x86_64") {
          dir("release") {
            deleteDir()
          }
          dir("build") {
            deleteDir()
          }
          sh "make -C '${WORKSPACE}' linux TARGET_ARCH=x86_64 REVISION=${env.kernelRevision} KERNEL_SRC_DIR='${WORKSPACE}/kernel' BUILD_DIR='${WORKSPACE}/x86_64/build' RELEASE_DIR='${WORKSPACE}/x86_64/release'"
        }
      }
    }
    stage('Archive kernels') {
      steps {
        archive includes: '*/release/**'
      }
    }
  }
  post {
    success {
      emailext(
        to: "jtamba@online.net",
        subject: "Kernel build - ${env.JOB_NAME} #${env.BUILD_NUMBER}: ${env.kernelVersion} available for release",
        body: """<p>Start a test and release job from <a href="${env.JENKINS_URL}/blue/organizations/jenkins/kernel-release">here</a></p>
          <p>Or start it directly with ubuntu on a <a href="${env.JENKINS_URL}/job/kernel-release/buildWithParameters?buildBranch=mainline%2Flatest&buildNumber=${env.BUILD_NUMBER}&arch=x86_64&testServerType=VC1S&testImage=ubuntu-xenial">VC1S</a>, a <a href="${env.JENKINS_URL}/job/kernel-release/buildWithParameters?buildBranch=mainline%2Flatest&buildNumber=${env.BUILD_NUMBER}&arch=arm&testServerType=C1&testImage=ubuntu-xenial">C1</a> or an <a href="${env.JENKINS_URL}/job/kernel-release/buildWithParameters?buildBranch=mainline%2Flatest&buildNumber=${env.BUILD_NUMBER}&arch=arm64&testServerType=ARM64-2GB&testImage=ubuntu-xenial">ARM64-2GB</a></p>
          <p>See the job <a href="${env.BUILD_URL}">here</a> (<a href="${env.BUILD_URL}/artifact">artifacts</a>)</p>
          """
      )
    }
  }
}


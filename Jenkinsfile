pipeline {
    agent {
        node {
            label 'localhost'
        }
    }

    environment {
        // 远程服务器地址
        DEPLOY_SERVER_IP = '192.168.11.54'
        
        // 远程服务器部署路径
        DEPLOY_PATH = '/vagrant/remotepackage/art/art'
        
        // SSH 凭据 ID
        SSH_CREDENTIALS_ID = 'ssh-warehouse-key' 
    }

    parameters {
        string(name: 'version', defaultValue: '0.16.0', description: '大版本号')
        string(name: 'tarFile', description: '打包的文件名')
    }

    options {
        timestamps() // 日志显示时间戳
        timeout(time: 1, unit: 'MINUTES') // 设置超时时间
        disableConcurrentBuilds() // 禁用并发构建
    }

    stages {
        stage('打包程序') {
            steps {
                script {
                    def tarFileName = "${params.tarFile}"
                    def tempDir = "/tmp/art-build-${env.BUILD_NUMBER}"

                    // 删除 .git 等文件
                    sh 'rm -rf .git .gitignore'

                    // 创建 logs 目录结构
                    sh 'mkdir -p art-oes/logs art-mds/logs'

                    // 创建临时目录并复制内容
                    sh "mkdir -p ${tempDir}"
                    sh "cp -r * ${tempDir}/"

                    // 打包临时目录内容
                    sh "cd ${tempDir} && tar -czf ${tarFileName} *"

                    // 将生成的 tar.gz 移回当前目录
                    sh "mv ${tempDir}/${tarFileName} ."

                    // 清理临时目录
                    sh "rm -rf ${tempDir}"
                }
            }
        }

        stage('上传成品库') {
            steps {
                script {
                    def tarFileName = "${params.tarFile}"
                    def remoteDir = "${env.DEPLOY_PATH}/${params.version}"
                    def remoteFullPath = "${remoteDir}/${tarFileName}"

                    withCredentials([sshUserPrivateKey(
                        credentialsId: env.SSH_CREDENTIALS_ID,
                        usernameVariable: 'SSH_USER',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        sh """
                            ssh -i \${SSH_KEY} \${SSH_USER}@\${DEPLOY_SERVER_IP} "mkdir -p ${remoteDir}"
                            scp -i \${SSH_KEY} ${tarFileName} \${SSH_USER}@\${DEPLOY_SERVER_IP}:${remoteFullPath}
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // 清理所有构建产物
                sh 'rm -rf *'
            }
            echo "已清理构建产物。"
        }
        success {
            echo "构建成功。"
        }
        failure {
            echo "构建失败，请检查日志。"
        }
    }
}
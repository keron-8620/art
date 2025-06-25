pipeline {
    agent {
        node {
            label 'localhost'
        }
    }
    triggers {
        GenericTrigger(
            genericVariables: [[key: 'ref', value: '$.ref', regexpFilter: '']],
            token: 'art',
            tokenCredentialId: '',
            regexpFilterText: '$.ref',
            regexpFilterExpression: ''
        )
    }

    environment {
        // 远程服务器地址
        DEPLOY_SERVER_IP = '192.168.11.54'
        
        // 远程服务器部署路径
        DEPLOY_PATH = '/vagrant/remotepackage/art'
        
        // SSH 凭据 ID
        SSH_CREDENTIALS_ID = 'ssh-warehouse-key' 
    }

    options {
        timestamps() // 日志显示时间戳
        timeout(time: 1, unit: 'MINUTES') // 设置超时时间
        disableConcurrentBuilds() // 禁用并发构建
    }

    stages {
        stage('获取版本号') {
            steps {
                script {
                    env.version = "${env.ref}".substring("refs/tags/".length())
                }
            }
        }
        stage('打包程序') {
            steps {
                script {
                    def tarFileName = "art-${env.version}.tar.gz"
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
                    def tarFileName = "art-${env.version}.tar.gz"
                    def parts = "${version}".split("\\.")
                    def remoteDir = "${env.DEPLOY_PATH}/${parts[0..2].join(".")}"
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
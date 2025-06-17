pipeline {
    agent {
        node {
            label 'art'
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
                    // 在项目目录下创建 logs 文件夹
                    sh 'mkdir -p art-oes/logs'
                    sh 'mkdir -p art-mds/logs'

                    // 使用传入的版本号构建文件名
                    def tarFileName = "${params.tarFile}"
                    
                    // 打包当前目录为 tar.gz
                    sh "tar -czf ${tarFileName} --exclude=${tarFileName} ."
                }
            }
        }
        stage('上传成品库') {
            steps {
                script {
                    def tarFileName = "${params.tarFile}"
                    def remoteDir = "${env.DEPLOY_PATH}/${params.version}"
                    def remoteFullPath = "${remoteDir}/${tarFileName}"

                    // 清理git相关信息
                    sh "rm -rf .git .gitignore"

                    // 创建远程目录
                    sshExec(
                        host: env.DEPLOY_SERVER_IP,
                        credentialsId: env.SSH_CREDENTIALS_ID,
                        command: "mkdir -p ${remoteDir}"
                    )

                    // 上传文件
                    sshPut(
                        host: env.DEPLOY_SERVER_IP,
                        credentialsId: env.SSH_CREDENTIALS_ID,
                        files: [
                            [from: tarFileName, into: remoteFullPath]
                        ]
                    )
                }
            }
        }
    }

    post {
        always {
            script {
                // 保留 Jenkinsfile，删除其余所有 Git 拉取和构建生成的内容
                sh '''
                    ls | grep -v '^Jenkinsfile$' | xargs rm -rf
                '''
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
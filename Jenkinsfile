pipeline {
    agent {
        node {
            label: 'art'
        }
    }

    parameters {
        // string(name: 'version', description: '版本号')
        string(name: 'tarFile', description: '打包的文件名')
    }

    options {
        timestamps() // 日志显示时间戳
        timeout(time: 1, unit: 'MINUTES') // 设置超时时间
        disableConcurrentBuilds() // 禁用并发构建
    }

    stages {

        stage('将程序打包') {
            steps {
                script {
                    // 在项目目录下创建 logs 文件夹
                    sh 'mkdir -p art-oes/logs'
                    sh 'mkdir -p art-mds/logs'

                    // 使用传入的版本号构建文件名
                    def tarFileName = "${params.tarFile}"
                    
                    // 打包当前目录为 tar.gz
                    sh "tar -czf ${tarFileName} *"

                    sh "pwd"
                }
            }
        }
    }

    post {
        success {
            echo "构建成功，项目已打包为 tar 并保存到 Jenkins 用户根目录。"
        }
        failure {
            echo "构建失败，请检查日志。"
        }
    }
}
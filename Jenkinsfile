pipeline {
    agent any

    parameters {
        string(name: 'version', description: '请输入版本号')
    }

    stages {
        stage('Clone Repository') {
            steps {
                // 从 Git 仓库拉取代码
                git url: 'https://gitee.com/danqingzhao/art.git',
                credentialsId: 'gitee-repo',
                branch: 'master'  // 替换为你需要的分支
            }
        }

        stage('Create Logs Directory') {
            steps {
                script {
                    // 在项目根目录下创建 logs 文件夹
                    sh 'mkdir -p logs'
                }
            }
        }

        stage('Archive Project as Tar') {
            steps {
                script {
                    // 使用传入的版本号构建文件名
                    def tarFileName = "art-${params.version}.tar.gz"
                    
                    // 打包当前目录为 tar.gz
                    sh "tar -czf ${tarFileName} *"

                    // 可选：将生成的 tar 文件移动到 Jenkins 用户根目录（假设路径是 /home/jenkins）
                    sh "mv ${tarFileName} /home/jenkins/"
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
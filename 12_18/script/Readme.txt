1、环境准备
    1）测试的工程应按照提交说明的格式，并置于submission文件夹下

2、运行
    在本目录下启动终端，运行以下命令
     vivado -mode batch -source script.tcl
    
   启动后，运行以下命令
     init all
   init命令会在本目录project/目录里生成功能测试、记忆游戏测试、性能测试和系统测试的vivado工程。
   
   之后，再运行：
     runall
   runall命令会对本目录project/目录里的功能测试、记忆游戏测试、性能测试和系统测试的vivado工程，运行综合并生产bit流文件。


   如果runall有错，请在本目录project/目录里打开对应的vivado工程，查看错误原因，确认提交的源码是否符合规范，修改后重新执行init和runall命令。
   如果runall顺利执行，则会在本目录result/目录里生成对应的bit流文件，请下板确认这些bit流文件是否可以正确运行。

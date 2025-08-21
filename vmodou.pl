#!/usr/bin/perl
#vModou - 兀雨墨斗古籍扫描页变形纠正工具
#by shanleiguang@gmail.com, 2025/8
use strict;
use warnings;

use Image::Magick;
use Getopt::Long;
use Data::Dumper;
use Encode;
use utf8;

$| = 1; #autoflush

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my ($software, $version) = ('vModou', 'v1.0');
#参数默认值
my ($tid, $bid, $sid, $nd, $ng) = (1, '02', '0010_0', '', ''); #nd：不做变形，仅做裁剪；ng：负片反转
my $ft = 'jpg'; #图片类型
my $help; #是否打印帮助
my $td = 50; #测试线间距
my $tf = 'Courier'; #测试信息字体
my ($ks, $kr) = (2, 0.8); #四角顶点识别像素块尺寸及有效像素占比
my ($ml, $mr, $mt, $mb) = (50, 50, 200, 200); #内容区域左、右、上、下间距
my ($m1, $m2, $m3, $m4) = (0.2, 0.8, 0.2, 0.8); #内容区域中部剔除，仅保留扫描顶点所需的四角，数值为内容区域长宽的比例
my ($pa, $pb, $pc, $pd) = (0, 0, 0, 0); #程序自动选择顶点不准确时手工选定扫描四角顶点序号，1或2
my ($da, $db, $dc, $dd) = ('0,0', '0,0', '0,0', '0,0'); #顶点坐标选定后X、Y坐标微调
my ($cl, $cr, $ct, $cb) = (0, 0, 0, 0); #最终裁剪区域左、右、上、下间距
my ($sw, $sh, $sd) = (1, 1, 0); #最终宽、高度调整比例及旋转角度
my $sp = 'A'; #变形标准参照点，A、B，默认左上角顶点A
my @dms = ('Perspective', 'Affine', 'Bilinear');
my $dm = 0; #Distort变形方法

GetOptions(
    'h'    => \$help,
    'b=s'  => \$bid, #书籍ID
    'nd'   => \$nd,  #无变形仅裁剪
    't=i'  => \$tid, #是否测试模式，默认为1
    'i=s'  => \$sid, #图片ID
    'ft=s' => \$ft,  #图片后缀
    'ng'   => \$ng,  #负片反转
    'ks=i' => \$ks,  #四角顶点识别像素块尺寸，默认2x2像素
    'kr=f' => \$kr,  #四角顶点识别像素块内有效像素占比，默认0.8
    'td=i' => \$td,  #测试线间距
    'ml=i' => \$ml,  #内容区域左间距
    'mr=i' => \$mr,  #内容区域右间距
    'mt=i' => \$mt,  #内容区域上间距
    'mb=i' => \$mb,  #内容区域下间距
    'm1=f' => \$m1,  #剔除区域1线
    'm2=f' => \$m2,  #剔除区域2线
    'm3=f' => \$m3,  #剔除区域3线
    'm4=f' => \$m4,  #剔除区域4线
    'cl=i' => \$cl,  #裁切左边距
    'cr=i' => \$cr,  #裁切右边距
    'ct=i' => \$ct,  #裁切上边距
    'cb=i' => \$cb,  #裁切下边距
    'pa=i' => \$pa,  #指定A点，1、2
    'pb=i' => \$pb,  #指定B点，1、2
    'pc=i' => \$pc,  #指定C点，1、2
    'pd=i' => \$pd,  #指定D点，1、2
    'da=s' => \$da,  #A点新坐标微调，默认为0,0，如2,-2代表A点坐标X、Y微调
    'db=s' => \$db,  #B点新坐标微调，默认为0,0
    'dc=s' => \$dc,  #C点新坐标微调，默认为0,0
    'dd=s' => \$dd,  #D点新坐标微调，默认为0,0
    'sp=s' => \$sp,  #变形参照点，A、B，默认为A
    'dm=i' => \$dm,  #变形方法
    'sw=f' => \$sw,  #最终宽度调整，默认为1
    'sh=f' => \$sh,  #最终高度调整，默认为1
    'sd=f' => \$sd,  #最终旋转角度，默认为0
);
#不同书籍的扫描图效果不同，默认参数可能不合适，这时可在书籍目录下的vmodou.cfg文件预设相关参数，如ft、ng、td、ml等，可有效减少命令行参数长度
my $vmcfg = "books/$bid/vmodou.cfg";
if(-f $vmcfg) {
    my %vm;
    open VMONFIG, "< $vmcfg";
    print "读取预设参数'$vmcfg'，注意：命令行参数优先！\n";
    while(<VMONFIG>) {
        chomp;
        next if(m/^\s{0,}$/);
        next if(m/^#/);
        s/#.*$// if(not m/=#/);
        s/\s//g;
        my ($k, $v) = split /=/, $_;
        $v = decode('utf-8', $v);
        $vm{$k} = $v;
    }
    close(VMONFIG);
    #命令行未修改参数默认值时才使用配置文件的参数
    $ft = $vm{'ft'} if($vm{'ft'} and $ft eq 'jpg');
    $ng = $vm{'ng'} if($vm{'ng'} and not $ng);
    $ml = $vm{'ml'} if($vm{'ml'} and $ml == 50);
    $mr = $vm{'mr'} if($vm{'mr'} and $mr == 50);
    $mt = $vm{'mt'} if($vm{'mt'} and $mt == 200);
    $mb = $vm{'mb'} if($vm{'mb'} and $mb == 200);
    $m1 = $vm{'m1'} if($vm{'m1'} and $m1 == 0.2);
    $m2 = $vm{'m2'} if($vm{'m2'} and $m2 == 0.8);
    $m3 = $vm{'m3'} if($vm{'m3'} and $m3 == 0.2);
    $m4 = $vm{'m4'} if($vm{'m4'} and $m4 == 0.8);
    $sp = $vm{'sp'} if($vm{'sp'} and $sp eq 'A');
    $dm = $vm{'dm'} if($vm{'dm'} and $dm == 0);
}

print_help() and exit if(defined $help);

if(not -d "books/$bid") {
    print "错误: 无 'books/$bid' 书籍目录！\n";
    exit;
}

my $srcdir = "books/$bid/src";
my $tmpdir = "books/$bid/tmp";
my $dstdir = "books/$bid/dst";
my $srcfn = "$srcdir/$sid.$ft";
my $tmpfn = $tmpdir.'/'.$sid.'.jpg';
my $dstfn = $dstdir.'/'.$sid.'.jpg';

if(not -f $srcfn) {
    print "错误：无 '$srcfn' 原扫描图文件！\n";
    exit;
}

$tid = 1 if(not -f $tmpfn); #必须先进行测试
print_info(); #打印当前运行参数

my $simg = Image::Magick->new; #原扫描图
my ($timg, $mimg, $dimg); #$timg：测试图层1，添加辅助线及参数等非图像本身内容的测试数据；$ming：测试图层2，为测试图添加图像相关内容；$dimg：最终执行变形图
my ($iw, $ih); #原图宽、高

$simg->ReadImage($srcfn);
$simg->Colorspace('RGB'); #设置为RGB色彩空间
$simg->Negate() if($ng); #反转
($iw, $ih) = ($simg->Get('width'), $simg->Get('height'));
print "读取原始扫描图'$srcfn'（$iw x $ih）\n";
$dimg = $simg->Clone(); #该图层仅根据测试图层计算的变形参数执行变形，生成最终结果
if($nd) {
    $dimg->Crop(x => $cl, y => $ct, width => $iw-$cl-$cr, height => $ih-$ct-$cb);
    $dimg->Write($dstfn);
    print "生成'$dstfn'，无变形仅裁剪！\n";
    exit;
}
$timg = $simg->Clone(); #用于计算变形参数及打印测试参数，计算变形参数前不打印测试参数，避免扫描干扰
$timg->Quantize(colorspace => 'gray'); #转换为灰度
$timg->Contrast(sharpen => 1); #增强对比度
$timg->CannyEdge('0x1+10%+40%'); #提取边缘
$timg->Morphology(method=>'Close', kernel=>'Rectangle:10x1'); #增强水平线
$timg->Morphology(method=>'Close', kernel=>'Rectangle:1x10'); #增强垂直线
$timg->Transparent('black'); #去除黑色
$mimg = $timg->Clone(); #测试图当前状态备份，用于叠加到侧视图完善测试效果
$timg->Draw(primitive => 'rectangle', points => get_2points(0,$mt+($ih-$mt-$mb)*$m1,$iw,$mt+($ih-$mt-$mb)*$m2), fill => 'black'); #剔除，用黑色覆盖
$timg->Draw(primitive => 'rectangle', points => get_2points($ml+($iw-$ml-$mr)*$m3,0,$ml+($iw-$ml-$mr)*$m4,$ih), fill => 'black'); #提取，用黑色覆盖
$timg->Transparent('black'); #去除黑色，即剔除黑色覆盖区域

#默认是测试模式，先确定扫描区域等参数，确保四角落入扫描区域且尽量避免含入干扰内容
#-t 0：非测试模式才进行扫描
if($tid == 0) {
    my (@A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2); #左上A、右上B、右下C、左下D四角区域，每个区域采用两种扫描策略，得到1、2两可选顶点的坐标
    my (@A, @B, @C, @D); #选定后的顶点坐标
    my (@NA, @NB, @NC, @ND); #以顶点A为基准，重新计算变形后B、C、D顶点坐标

    #左上区域，0、1两种扫描策略，得到A1、A2
    @A1 = find_point($ml, $mt, $iw/4-$ml, $ih/4-$mt, 0, $ks); #中部已抹去，用1/4比例即可覆盖
    @A2 = find_point($ml, $mt, $iw/4-$ml, $ih/4-$mt, 1, $ks);
    #右上区域
    @B1 = find_point($iw*3/4, $mt, $iw/4-$mr, $ih/4-$mt, 2, $ks);
    @B2 = find_point($iw*3/4, $mt, $iw/4-$mr, $ih/4-$mt, 3, $ks);
    #右下区域
    @C1 = find_point($iw*3/4, $ih*3/4, $iw/4-$mr, $ih/4-$mb, 4, $ks);
    @C2 = find_point($iw*3/4, $ih*3/4, $iw/4-$mr, $ih/4-$mb, 5, $ks);
    #左下区域
    @D1 = find_point($ml, $ih*3/4, $iw/4-$ml, $ih/4-$mb, 6, $ks);
    @D2 = find_point($ml, $ih*3/4, $iw/4-$ml, $ih/4-$mb, 7, $ks);
    #程序自动选定四角顶点规则
    @A = ($A1[0] < $A2[0]) ? @A1 : @A2; #左上角顶点，取X值小靠内的
    @B = ($B1[0] > $B2[0]) ? @B1 : @B2; #右上角顶点，取X值大靠外的
    @C = ($C1[1] > $C2[1]) ? @C1 : @C2; #右下角顶点，取Y值大靠外的
    @D = ($D1[0] < $D2[0]) ? @D1 : @D2; #左下角顶点，取X值小靠内的
    #检查测试图，若不是合理顶点，通过'-pa -pb -pc -pd'参数手工指定
    @A = ($pa == 1) ? @A1 : ($pa == 2) ? @A2 : @A;
    @B = ($pb == 1) ? @B1 : ($pb == 2) ? @B2 : @B;
    @C = ($pc == 1) ? @C1 : ($pc == 2) ? @C2 : @C;
    @D = ($pd == 1) ? @D1 : ($pd == 2) ? @D2 : @D;
    #更新选定顶点序号，用于打印选点信息
    $pa = ($A[0] == $A1[0] and $A[1] == $A1[1]) ? 1 : 2;
    $pb = ($B[0] == $B1[0] and $B[1] == $B1[1]) ? 1 : 2;
    $pc = ($C[0] == $C1[0] and $C[1] == $C1[1]) ? 1 : 2;
    $pd = ($D[0] == $D1[0] and $D[1] == $D1[1]) ? 1 : 2;
    print "扫描四角顶点：A$pa B$pb C$pc D$pd\n";
    #为选定顶点添加红色外框提示
    $timg->Draw(primitive => 'rectangle', points => get_2points($A[0]-5,$A[1]+5,$A[0]+$td/2+10,$A[1]-$td/2-10),
        fill => 'transparent', stroke => 'red', strokewidth => 1);
    $timg->Annotate(text => 'A1', font => $tf, pointsize => $td/2, x => $A1[0], y => $A1[1], fill => 'red');
    $timg->Annotate(text => 'A2', font => $tf, pointsize => $td/2, x => $A2[0], y => $A2[1], fill => 'red');
    $timg->Draw(primitive => 'rectangle', points => get_2points($B[0]-5,$B[1]+5,$B[0]+$td/2+10,$B[1]-$td/2-10),
        fill => 'transparent', stroke => 'red', strokewidth => 1);
    $timg->Annotate(text => 'B1', font => $tf, pointsize => $td/2, x => $B1[0], y => $B1[1], fill => 'red');
    $timg->Annotate(text => 'B2', font => $tf, pointsize => $td/2, x => $B2[0], y => $B2[1], fill => 'red');
    $timg->Draw(primitive => 'rectangle', points => get_2points($C[0]-5,$C[1]+5,$C[0]+$td/2+10,$C[1]-$td/2-10),
        fill => 'transparent', stroke => 'red', strokewidth => 1);
    $timg->Annotate(text => 'C1', font => $tf, pointsize => $td/2, x => $C1[0], y => $C1[1], fill => 'red');
    $timg->Annotate(text => 'C2', font => $tf, pointsize => $td/2, x => $C2[0], y => $C2[1], fill => 'red');
    $timg->Draw(primitive => 'rectangle', points => get_2points($D[0]-5,$D[1]+5,$D[0]+$td/2+10,$D[1]-$td/2-10),
        fill => 'transparent', stroke => 'red', strokewidth => 1);
    $timg->Annotate(text => 'D1', font => $tf, pointsize => $td/2, x => $D1[0], y => $D1[1], fill => 'red');
    $timg->Annotate(text => 'D2', font => $tf, pointsize => $td/2, x => $D2[0], y => $D2[1], fill => 'red');
    #计算顶点变形坐标
    if($sp eq 'A') { #以左上角顶点A为标准参照点，计算B、C、D点变形后的新坐标
        @NA = @A;
        $NB[0] = $A[0]+distance_2points(@A, @B);
        $NB[1] = $A[1];
        $ND[0] = $A[0];
        $ND[1] = $A[1]+distance_2points(@A, @D);
        $NC[0] = $NB[0];
        $NC[1] = $ND[1];
    }
    if($sp eq 'B') { #以右上角顶点B为标准参照点，#计算A、C、D点变形后的新坐标
        $NA[0] = $B[0]-distance_2points(@B, @A);
        $NA[1] = $B[1];
        @NB = @B;
        $NC[0] = $B[0];
        $NC[1] = $B[1]+distance_2points(@B, @C);
        $ND[0] = $NA[0];
        $ND[1] = $NC[1];
    }
    #观察变形效果，对顶点变形坐标手工微调
    @NA = points_deltaxy($da, \@NA) if($da ne '0,0');
    @NB = points_deltaxy($db, \@NB) if($db ne '0,0');
    @NC = points_deltaxy($dc, \@NC) if($dc ne '0,0');
    @ND = points_deltaxy($dd, \@ND) if($dd ne '0,0');
    #最终图根据上述参数变形
    $dimg->Distort(
        'virtual-pixel' => 'black',
        method => $dms[$dm],
        points => [ @A,@NA, @B,@NB, @C,@NC, @D,@ND ],
    );
    #宽高比例调整
    if($sw !~ 1 or $sh !~ 1) {
        $dimg->Distort(
            'virtual-pixel' => 'black',
            method => 'Bilinear',
            points => [ 0,0,0,0, $iw,0,$iw*$sw,0, $iw,$ih,$iw*$sw,$ih*$sh, 0,$ih,0,$ih*$sh],
        );
    }
    #图像变形后旋转
    if($sd !~ 0) { $dimg->Rotate(degrees => $sd, background => 'black'); }
    #选定四顶点连线
    $timg->Draw(primitive => 'line', points => get_2points(@A, @B), fill => 'transparent', stroke => 'red', strokewidth => 4);
    $timg->Draw(primitive => 'line', points => get_2points(@B, @C), fill => 'transparent', stroke => 'red', strokewidth => 4);
    $timg->Draw(primitive => 'line', points => get_2points(@C, @D), fill => 'transparent', stroke => 'red', strokewidth => 4);
    $timg->Draw(primitive => 'line', points => get_2points(@D, @A), fill => 'transparent', stroke => 'red', strokewidth => 4);
}

#为测试图层添加更多辅助信息
#辅助线
foreach my $i (0..int($iw/$td)) {
    my ($fx, $fy) = ($i*$td, 0);
    my ($tx, $ty) = ($i*$td, $ih);
    $timg->Draw(primitive => 'line', points => get_2points($fx,$fy,$tx,$ty), fill => 'gray');
}
foreach my $j (0..int($ih/$td)) {
    my ($fx, $fy) = (0, $j*$td);
    my ($tx, $ty) = ($iw, $j*$td);
    $timg->Draw(primitive => 'line', points => get_2points($fx,$fy,$tx,$ty), fill => 'gray');
}
#原图尺寸信息
$timg->Annotate(text => "$iw x $ih", font => $tf, pointsize => $td*3/4, x=>$iw/2-$td*3, y => $td,
    fill => 'white', undercolor => 'gray');
#备份图层的内容区域，绿色透明
$mimg->Draw(primitive => 'rectangle', points => get_2points($ml,$mt,$iw-$mr,$ih-$mb), fill => 'green'); 
#备份图层的中部剔除区域，灰色透明
$mimg->Draw(primitive => 'rectangle', points => get_2points($ml,$mt+($ih-$mt-$mb)*$m1,$iw-$mr,$mt+($ih-$mt-$mb)*$m2), fill => '#666666'); 
$mimg->Draw(primitive => 'rectangle', points => get_2points($ml+($iw-$ml-$mr)*$m3,$mt,$ml+($iw-$ml-$mr)*$m4,$ih-$mb), fill => '#666666');
#添加测试参数数据
#顶点相关参数
$timg->Annotate(text => 'A', font => 'Courier', pointsize => $td, x => $td/2, y => $mt-$td/2,
    fill => 'red', stroke => 'red', strokewidth => 1);
$timg->Annotate(text => 'B', font => 'Courier', pointsize => $td, x => $iw-$td, y => $mt-$td/2,
    fill => 'red', stroke => 'red', strokewidth => 1);
$timg->Annotate(text => 'C', font => 'Courier', pointsize => $td, x => $iw-$td, y => $ih-$mb+$td,
    fill => 'red', stroke => 'red', strokewidth => 1);
$timg->Annotate(text => 'D', font => 'Courier', pointsize => $td, x => $td/2, y => $ih-$mb+$td,
    fill => 'red', stroke => 'red', strokewidth => 1);
#内容区域相关参数
$timg->Annotate(text => "-ml $ml, -mr $mr, -mt $mt, -mb $mb", font => $tf, pointsize => $td*3/4, x=>$iw/2-$td*7.5, y => $ih-$mb+$td,
    fill => 'white', undercolor => 'green');
#内容剔除区域提示线及相关参数
$timg->Draw(primitive => 'line', points => get_2points(0,$mt+($ih-$mt-$mb)*$m1,$iw,$mt+($ih-$mt-$mb)*$m1),
    stroke => 'blue', strokewidth => 5);
$timg->Draw(primitive => 'line', points => get_2points(0,$mt+($ih-$mt-$mb)*$m2,$iw,$mt+($ih-$mt-$mb)*$m2),
    stroke => 'blue', strokewidth => 5);
$timg->Draw(primitive => 'line', points => get_2points($ml+($iw-$ml-$mr)*$m3,0,$ml+($iw-$ml-$mr)*$m3,$ih),
    stroke => 'blue', strokewidth => 5);
$timg->Draw(primitive => 'line', points => get_2points($ml+($iw-$ml-$mr)*$m4,0,$ml+($iw-$ml-$mr)*$m4,$ih),
    stroke => 'blue', strokewidth => 5);
$timg->Annotate(text => "-m1 $m1", font => $tf, pointsize => $td*3/4, x=>$iw/2-$td, y => $mt+($ih-$mt-$mb)*$m1+$td/2,
    fill => 'white', undercolor => 'blue', stroke => 'white', strokewidth => 1);
$timg->Draw(primitive => 'line', points => get_2points($iw/2,$mt+($ih-$mt-$mb)*$m1,$iw/2,$mt),
    fill => 'transparent', 'stroke-dasharray' => [10,5], stroke => 'blue', strokewidth => 4);
$timg->Annotate(text => "-m2 $m2", font => $tf, pointsize => $td*3/4, x=>$iw/2-$td, y => $mt+($ih-$mt-$mb)*$m2-$td/4,
    fill => 'white', undercolor => 'blue', stroke => 'white', strokewidth => 1);
$timg->Draw(primitive => 'line', points => get_2points($iw/2,$mt+($ih-$mt-$mb)*$m2,$iw/2,$ih-$mb),
    fill => 'transparent', 'stroke-dasharray' => [10,5], stroke => 'blue', strokewidth => 4);
$timg->Annotate(text => "-m3 $m3", font => $tf, pointsize => $td*3/4, x=>$ml+($iw-$ml-$mr)*$m3+$td/4, y => $ih/2-$td,
    fill => 'white', undercolor => 'blue', stroke => 'white', strokewidth => 1, rotate => 90);
$timg->Draw(primitive => 'line', points => get_2points($ml+($iw-$ml-$mr)*$m3,$ih/2,$ml,$ih/2),
    fill => 'transparent', 'stroke-dasharray' => [10,5], stroke => 'blue', strokewidth => 4);
$timg->Annotate(text => "-m4 $m4", font => $tf, pointsize => $td*3/4, x=>$ml+($iw-$ml-$mr)*$m4-$td/2, y => $ih/2-$td,
    fill => 'white', undercolor => 'blue', stroke => 'white', strokewidth => 1, rotate => 90);
$timg->Draw(primitive => 'line', points => get_2points($ml+($iw-$ml-$mr)*$m4,$ih/2,$iw-$mr,$ih/2),
    fill => 'transparent', 'stroke-dasharray' => [10,5], stroke => 'blue', strokewidth => 4);
#测试图层整合
$simg->Modulate(brightness => 75);
$simg->Composite(image => $mimg, compose => 'Screen');
$simg->Composite(image => $timg, compose => 'Over');

#扩展长宽，在扩展区域添加辅助信息
my $cw = $td/2*14; #打线图与效果图之间的宽度
my $title = 'vModou -Distortion correction for scanned images of ancient books';
#扩展测试图
$simg->Extent(x => -$td*2, y => -$td*2, width => $iw+$td*2+$cw, height => $ih+$td*4, background => '#cccccc');
#辅助线坐标
foreach my $i (0..int($iw/$td)) {
    my ($ix, $iy) = ($i*$td+$td*2, $td);
    $simg->Annotate(text => $i, font => $tf, pointsize => $td/2, x => $ix, y => $iy, fill => 'black');
}
foreach my $j (0..int($ih/$td)) {
    my ($jx, $jy) = ($td, $j*$td+$td*2);
    $simg->Annotate(text => $j, font => $tf, pointsize => $td/2, x => $jx, y => $jy, fill => 'black');
}
#测试图中间打印几类参数
#顶点参数
$simg->Annotate(text => "1-Points", font => $tf, pointsize => $td*3/4, x=>$iw+$td*2.5, y => $td*6,
    fill => 'black', stroke => 'black', strokewidth => 1, decorate => 'underline');
$simg->Annotate(text => "A:A$pa", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*7, fill => 'black');
$simg->Annotate(text => "B:B$pb", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*8, fill => 'black');
$simg->Annotate(text => "C:C$pc", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*9, fill => 'black');
$simg->Annotate(text => "D:D$pd", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*10, fill => 'black');
#变形参数
$simg->Annotate(text => "2-Distort", font => $tf, pointsize => $td*3/4, x=>$iw+$td*2.5, y => $td*11,
    fill => 'black', stroke => 'black', strokewidth => 1, decorate => 'underline');
$simg->Annotate(text => "-sp $sp", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*12, fill => 'black');
$simg->Annotate(text => "-dm $dm", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*13, fill => 'black');
$simg->Annotate(text => "-da $da", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*14, fill => 'black');
$simg->Annotate(text => "-db $db", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*15, fill => 'black');
$simg->Annotate(text => "-dc $dc", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*16, fill => 'black');
$simg->Annotate(text => "-dd $dd", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*17, fill => 'black');
#拉伸参数
$simg->Annotate(text => "3-Stretch", font => $tf, pointsize => $td*3/4, x=>$iw+$td*2.5, y => $td*18,
    fill => 'black', stroke => 'black', strokewidth => 1, decorate => 'underline');
$simg->Annotate(text => "-sw $sw", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*19, fill => 'black');
$simg->Annotate(text => "-sh $sh", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*20, fill => 'black');
#旋转参数
$simg->Annotate(text => "4-Rotate", font => $tf, pointsize => $td*3/4, x=>$iw+$td*2.5, y => $td*21,
    fill => 'black', stroke => 'black', strokewidth => 1, decorate => 'underline');
$simg->Annotate(text => "-sd $sd", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*22, fill => 'black');
#裁切参数
$simg->Annotate(text => "5-Crop", font => $tf, pointsize => $td*3/4, x=>$iw+$td*2.5, y => $td*23,
    fill => 'black', stroke => 'black', strokewidth => 1, decorate => 'underline');
$simg->Annotate(text => "-cl $cl", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*24, fill => 'black');
$simg->Annotate(text => "-cr $cr", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*25, fill => 'black');
$simg->Annotate(text => "-ct $ct", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*26, fill => 'black');
$simg->Annotate(text => "-cb $cb", font => $tf, pointsize => $td*3/4, x=>$iw+$td*3, y => $td*27, fill => 'black');
#测试图右侧进一步扩展，显示变形效果图
$simg->Extent(x => 0, y => 0, width => $iw+$td*2+$cw+$iw+$td, height => $ih+$td*4, background => '#cccccc');
$dimg->Crop(x => $cl, y => $ct, width => $iw-$cl-$cr, height => $ih-$ct-$cb);

my ($dw, $dh) = ($dimg->Get('width'), $dimg->Get('Height'));

$simg->Composite(image => $dimg, x => $iw+$td*2+$cw, y => $td*2, compose => 'Over'); #效果图整合到测试图右侧
$simg->Annotate(text => "$dw x $dh", font => $tf, pointsize => $td*3/4, x=>$iw*3/2+$cw, y => $td*3,
    fill => 'white', undercolor => 'gray');
$simg->Annotate(text => $title, font => $tf, pointsize => $td, x => ($iw*2+$td*3+$cw)/2-length($title)/2*$td/2, y => $ih+$td*3.25,
    fill => 'blue', stroke => 'blue', strokewidth => 1);

#测试图添加LOGO
my $logofn = 'images/logo.png';
my $modoufn = 'images/modou.png';

if(-f $logofn) {
    my $limg = Image::Magick->new();
    my $mimg = Image::Magick->new();
    $limg->ReadImage($logofn);
    $mimg->ReadImage($modoufn);
    my ($lw, $lh) = ($limg->Get('width'), $limg->Get('height'));
    my ($mw, $mh) = ($mimg->Get('width'), $mimg->Get('height'));
    my $lrw = 150; my $lrh = $lh/$lw*$lrw;
    my $mrw = 150; my $mrh = $lh/$lw*$mrw;
    $limg->AdaptiveResize(x => 0, y => 0, width => $lrw, height => $lrh, method => 'Hermite', blur => 0.618);
    $mimg->AdaptiveResize(x => 0, y => 0, width => $mrw, height => $mrh, method => 'Hermite', blur => 0.618);
    $simg->Composite(image => $limg, x => $iw+$td*2+$cw-$lrw*0.618, y => $dh-$td*2);
    $simg->Composite(image => $mimg, x => $iw+$td*2+$cw/2-$lrw*0.618, y => $td*2);
}

#存储测试图
$simg->Write($tmpfn);
print "生成测试图'$tmpfn'！\n";
#最终图裁切后存储
if($tid == 0) {
    $dimg->Write($dstfn);
    print "生成变形纠正图'$dstfn'！\n";
}

sub print_info {
    print '='x80, "\n";
    print "    $software $version，兀雨墨斗古籍扫描图变形纠正工具\n";
    print "\t作者：GitHub\@shanleiguang，小红书\@兀雨书屋，2025\n";
    print '='x80, "\n";
    print "  原扫描图：$srcfn\n";
    print '  测试模式：', ($tid == 1) ? '是' : '否', "\t测试线间距：$td\n";
    print "  顶点扫描像素块尺寸：$ks x $ks\t顶点扫描像素块有效像素门限：$kr\n";
    print "  内容区域参数：-ml $ml -mr $mr -mt $mt -mb $mb\n";
    print "  内容剔除参数：-m1 $m1 -m2 $m2 -m3 $m3 -m4 $m4\n";
    print "  四角顶点序号：-pa $pa -pb $pb -pc $pc -pd $pd，0-自动选择\n";
    print "  顶点变形微调：-da $da -db $db -dc $dc -dd $dd\n";
    print "  变形参考顶点：-sp $sp\t变形方法参数：$dms[$dm]\n";
    print "  变形拉伸参数：-sw $sw -sh $sh\t旋转角度：-sd $sd\n";
    print "  最终裁切参数：-cl $cl -cr $cr -ct $ct, -cb $cb\n";
    print '-'x80, "\n";
    print "**报错大概率是扫描区域参数不合适，未找到可选顶点，调整m类参数即可\n";
    print "**若可选顶点不合适，调整m类参数，尽量缩小四角扫描范围，减少扫描干扰\n";
    print "**若程序自选顶点不合适，调整p类参数，手工指定合适的可选顶点编号\n";
    print '='x80, "\n";
}

sub print_help {
    print <<END
   ./$software\t$version，兀雨墨斗古籍扫描图变形纠正工具
    -h\t帮助信息
    -t\t是否测试模式，测试模式不进行扫描和实际变形，默认开启为1，测试参数调试好后设置为0即可执行变形
    -b\t书籍ID
    -s\t书籍ID src目录下的图片名，不含后缀
    -td\t测试线间距，默认50像素
    -ml\t页面内容区域左边距，默认20像素
    -mr\t页面内容区域右边距，默认20像素
    -mt\t页面内容区域上边距，默认200像素
    -mb\t页面内容区域下边距，默认200像素
    -m1\t剔除区域1号线到内容区域上边距离与内容区域的高度比，默认0.1，越小越靠近
    -m2\t剔除区域2号线到内容区域下边距离与内容区域的高度比，默认0.9，越大越靠近
    -m3\t剔除区域3号线到内容区域左边距离与内容区域的宽度比，默认0.1，越小越靠近
    -m4\t剔除区域4号线到内容区域右边距离与内容区域的宽度比，默认0.9，越大越靠近
    -pa\t指定左上角扫描顶点A编号，1或2，默认自动选择
    -pb\t指定右上角扫描顶点B编号，1或2，默认自动选择
    -pc\t指定右下角扫描顶点C编号，1或2，默认自动选择
    -pd\t指定左下角扫描顶点D编号，1或2，默认自动选择
    -da\t顶点A新坐标微调，默认为0,0
    -db\t顶点B新坐标微调，默认为0,0
    -dc\t顶点C新坐标微调，默认为0,0
    -dd\t顶点D新坐标微调，默认为0,0
    -sw\t变形后宽度拉伸，默认为1
    -sh\t变形后长度拉伸，默认为1
    -sd\t变形后图像旋转，默认为0
    -cl\t变形后左黑边裁切，默认0像素
    -cr\t变形后右黑边裁切，默认0像素
    -ct\t变形后上黑边裁切，默认0像素
    -cb\t变形后下黑边裁切，默认0像素
    -sp\t变形标准参照顶点，A（左上）、B（右上），默认为A
    -dm\tDistort变形方法，0-Perspective，1-Affine，2-Bilinear，默认为0
        作者：GitHub\@shanleiguang，小红书\@兀雨书屋，2025
END
}

sub points_deltaxy {
    my ($d, $p) = @_;
    my ($dx, $dy) = split /\,/, $d;
    return ($p->[0]+$dx, $p->[1]+$dy);
}

#勾股定理法计算两点间距离
sub distance_2points {
    my ($fx, $fy, $tx, $ty) = @_;
    my ($dx, $dy) = ($tx-$fx, $ty-$fy);
    return sqrt($dx**2+$dy**2);
}

#顶点扫描方法，不同扫描策略
sub find_point {
    my ($x, $y, $w, $h, $t, $k) = @_;
    my ($px, $py);
    #0：从上到下，从左向右
    if($t == 0) {
        Y: foreach my $j ($y..$y+$h) {
            X: foreach my $i ($x..$x+$w) {
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/($#pixels) >= $kr) {
                    ($px, $py) = ($i, $j);
                    last Y;
                }
            }
        }
    }
    #1：从左向右，从上到下
    if($t == 1) {
        X: foreach my $i ($x..$x+$w) {
            Y: foreach my $j ($y..$y+$h) {            
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/($#pixels) >= $kr) {
                    ($px, $py) = ($i, $j);
                    last X;
                }
            }
        }
    }
    #2: top->bottom right->left
    if($t == 2) {
        Y: foreach my $j ($y..$y+$h) {
            X: foreach my $i (reverse $x..$x+$w) {
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/($#pixels) >= $kr) {
                    ($px, $py) = ($i, $j);
                    last Y;
                }
            }
        }
    }
    #3: right->left top->bottom
    if($t == 3) {
        X: foreach my $i (reverse $x..$x+$w) {
            Y: foreach my $j ($y..$y+$h) {     
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/($#pixels) >= $kr) {
                    ($px, $py) = ($i, $j);
                    last X;
                }
            }
        }
    }
    #4: bottom->top right->left
    if($t == 4) {
        Y: foreach my $j (reverse $y..$y+$h) {
            X: foreach my $i (reverse $x..$x+$w) {
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/$#pixels >= $kr) {
                    ($px, $py) = ($i, $j);
                    last Y;
                }
            }
        }
    }
    #5: right->left bottom->top
    if($t == 5) {
        X: foreach my $i (reverse $x..$x+$w) {
            Y: foreach my $j (reverse $y..$y+$h) {            
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/$#pixels >= $kr) {
                    ($px, $py) = ($i, $j);
                    last X;
                }
            }
        }
    }
    #6: bottom->top left->right
    if($t == 6) {
        Y: foreach my $j (reverse $y..$y+$h) {
            X: foreach my $i ($x..$x+$w) {
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/$#pixels >= $kr) {
                    ($px, $py) = ($i, $j);
                    last Y;
                }
            }
        }
    }
    #7: left->right bottom->top
    if($t == 7) {
        X: foreach my $i ($x..$x+$w) {
            Y: foreach my $j (reverse $y..$y+$h) {
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/$#pixels >= $kr) {
                    ($px, $py) = ($i, $j);
                    last X;
                }
            }
        }
    }
    return ($px, $py);
}
#计算有效像素数量
sub pixels_sum {
    my @pixels = @_;
    my $psum;
    foreach my $p (@pixels) { $psum+= $p;}
    return $psum;
}

sub get_2points {
    my ($x1, $y1, $x2, $y2) = @_;
    return "$x1,$y1 $x2,$y2";
}

sub get_3points {
    my ($x1, $y1, $x2, $y2, $x3, $y3) = @_;
    return "$x1,$y1 $x2,$y2 $x3,$y3";
}

sub get_points_ellipse {
    my ($fx, $fy, $tx, $ty) = @_;
    return "$fx,$fy $tx,$ty 0,360";
}
#!/usr/bin/perl
#by shanleiguang@gmail.com
use strict;
use warnings;

use Image::Magick;
use Getopt::Std;
use Data::Dumper;
use Encode;
use utf8;

my ($software, $version) = ('vModo', 'v1.0');
my %opts;

getopts('b:i:A:B:C:D:', \%opts);

if(not $opts{'b'} or not -d "books/$opts{'b'}") {
    print "error: no book id or 'books/$opts{'b'}' not found!\n";
    exit;
}
if(not $opts{'i'} or not -f "books/$opts{'b'}/src/$opts{'i'}.jpg") {
    print "error: no srcimg or 'books/$opts{'b'}/src/$opts{'i'}.jpg' not found!\n";
    exit;
}

my ($bid, $sid) = ($opts{'b'}, $opts{'i'});
my $srcdir = "books/$bid/src";
my $tmpdir = "books/$bid/tmp";
my $dstdir = "books/$bid/dst";
my $srcfn = $srcdir.'/'.$sid.'.jpg';
my $td = 50; #测试线间距
my ($ml, $mr, $mt, $mb) = (20, 30, 500, 200); #内容区域左、右、上、下间距
my ($m1, $m2, $m3, $m4) = (0.05, 0.9, 0.12, 0.88); #内容区域中部剔除，仅保留扫描顶点所需的四角，数值为内容区域长宽的比例
my ($cl, $cr, $ct, $cb) = (40, 10, 20, 35); #最终裁剪区域左、右、上、下间距
my $simg = Image::Magick->new; #原始图
my ($timg, $mimg, $dimg); #测试图，测试图中部剔除前备份图层，最终图
my ($iw, $ih); #原始图长、高

$simg->ReadImage($srcfn);
($iw, $ih) = ($simg->Get('width'), $simg->Get('height'));
$timg = $simg->Clone(); #用于计算变形参数及打印测试参数，计算变形参数前不打印测试参数，避免扫描干扰
$dimg = $simg->Clone(); #根据测试图计算的变形参数执行变形
$timg->Quantize(colorspace => 'gray'); #转换为灰度
$timg->Contrast(sharpen => 1); #增强对比度
$timg->CannyEdge('0x1+10%+40%'); #提取边缘
$timg->Morphology(method=>'Close', kernel=>'Rectangle:10x1'); #增强水平线
$timg->Morphology(method=>'Close', kernel=>'Rectangle:1x10'); #增强垂直线
$timg->Transparent('black'); #去除黑色
$mimg = $timg->Clone(); #侧视图当前状态备份
$timg->Draw(primitive => 'rectangle', points => get_2points(0,$mt+($ih-$mt-$mb)*$m1,$iw,$mt+($ih-$mt-$mb)*$m2), fill => 'black'); #黑色覆盖中部
$timg->Draw(primitive => 'rectangle', points => get_2points($ml+($iw-$ml-$mr)*$m3,0,$ml+($iw-$ml-$mr)*$m4,$ih), fill => 'black'); #黑色覆盖中部
$timg->Transparent('black'); #去除黑色

my (@A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2); #左上A、右上B、右下C、左下D四角区域，每个区域采用两种扫描策略，得到1、2两可选顶点的坐标
my (@A, @B, @C, @D); #选定后的顶点坐标
my (@NB, @NC, @ND); #以顶点A为基准，重新计算变形后B、C、D顶点坐标
my $k = 2; #识别规则，2x2区域内白色在80%以上

#左上区域，0、1两种扫描策略，得到A1、A2
@A1 = find_point($ml, $mt, $iw/4-$ml, $ih/4-$mt, 0, $k); #中部已抹去，用1/4比例即可覆盖
$timg->Annotate(text => 'A1', font => 'Curier', pointsize => $td/2, x => $A1[0], y => $A1[1], fill => 'red');
@A2 = find_point($ml, $mt, $iw/4-$ml, $ih/4-$mt, 1, $k);
$timg->Annotate(text => 'A2', font => 'Curier', pointsize => $td/2, x => $A2[0], y => $A2[1], fill => 'red');
#右上区域
@B1 = find_point($iw*3/4, $mt, $iw/4-$mr, $ih/4-$mt, 2, $k);
$timg->Annotate(text => 'B1', font => 'Curier', pointsize => $td/2, x => $B1[0], y => $B1[1], fill => 'red');
@B2 = find_point($iw*3/4, $mt, $iw/4-$mr, $ih/4-$mt, 3, $k);
#右下区域
$timg->Annotate(text => 'B2', font => 'Curier', pointsize => $td/2, x => $B2[0], y => $B2[1], fill => 'red');
@C1 = find_point($iw*3/4, $ih*3/4, $iw/4-$mr, $ih/4-$mb, 4, $k);
$timg->Annotate(text => 'C1', font => 'Curier', pointsize => $td/2, x => $C1[0], y => $C1[1], fill => 'red');
@C2 = find_point($iw*3/4, $ih*3/4, $iw/4-$mr, $ih/4-$mb, 5, $k);
$timg->Annotate(text => 'C2', font => 'Curier', pointsize => $td/2, x => $C2[0], y => $C2[1], fill => 'red');
#左下区域
@D1 = find_point($ml, $ih*3/4, $iw/4-$ml, $ih/4-$mb, 6, $k);
$timg->Annotate(text => 'D1', font => 'Curier', pointsize => $td/2, x => $D1[0], y => $D1[1], fill => 'red');
@D2 = find_point($ml, $ih*3/4, $iw/4-$ml, $ih/4-$mb, 7, $k);
$timg->Annotate(text => 'D2', font => 'Curier', pointsize => $td/2, x => $D2[0], y => $D2[1], fill => 'red');

#选定四角顶点的默认规则，检查测试图，若不是所需顶点，通过'-A -B -C -D'参数手工指定
@A = ($A1[0] < $A2[0]) ? @A1 : @A2; #取X值小靠内的
@B = ($B1[0] > $B2[0]) ? @B1 : @B2; #取X值大靠外的
@C = ($C1[1] > $C2[1]) ? @C1 : @C2; #取X值大靠外的
@D = ($D1[0] < $D2[0]) ? @D1 : @D2; #取X值小靠内的

#为选定顶点添加红色外框提示
$timg->Draw(primitive => 'rectangle', points => get_2points($A[0]-5,$A[1]+5,$A[0]+$td/2+10,$A[1]-$td/2-10),
    fill => 'transparent', stroke => 'red', strokewidth => 1);
$timg->Draw(primitive => 'rectangle', points => get_2points($B[0]-5,$B[1]+5,$B[0]+$td/2+10,$B[1]-$td/2-10),
    fill => 'transparent', stroke => 'red', strokewidth => 1);
$timg->Draw(primitive => 'rectangle', points => get_2points($C[0]-5,$C[1]+5,$C[0]+$td/2+10,$C[1]-$td/2-10),
    fill => 'transparent', stroke => 'red', strokewidth => 1);
$timg->Draw(primitive => 'rectangle', points => get_2points($D[0]-5,$D[1]+5,$D[0]+$td/2+10,$D[1]-$td/2-10),
    fill => 'transparent', stroke => 'red', strokewidth => 1);

#计算B、C、D点变形后的新坐标
$NB[0] = $A[0]+distance_2points(@A, @B);
$NB[1] = $A[1];
$NC[0] = $A[0]+distance_2points(@A, @B);
$NC[1] = $A[1]+distance_2points(@A, @D);
$ND[0] = $A[0];
$ND[1] = $A[1]+distance_2points(@A, @D);
#最终图根据上述参数变形
$dimg->Distort(
    'virtual-pixel' => 'transparent',
    method => 'Affine',
    points => [ @A,@A, @B,@NB, @C,@NC, @D,@ND ]
);

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
$timg->Draw(primitive => 'rectangle', points => get_2points($ml,$mt,$iw-$mr,$ih-$mb),
    fill => 'transparent', stroke => 'blue', strokewidth => 4);
$timg->Annotate(text => "Margins : L$ml, R$mr, T$mt, B$mb", font => 'Curier', pointsize => 30, x=>$iw/2-$td*6, y => $ih-$mb+$td, fill => 'blue');
$timg->Draw(primitive => 'line', points => get_2points(@A, @B), fill => 'transparent', stroke => 'red', strokewidth => 4);
$timg->Draw(primitive => 'line', points => get_2points(@B, @C), fill => 'transparent', stroke => 'red', strokewidth => 4);
$timg->Draw(primitive => 'line', points => get_2points(@C, @D), fill => 'transparent', stroke => 'red', strokewidth => 4);
$timg->Draw(primitive => 'line', points => get_2points(@D, @A), fill => 'transparent', stroke => 'red', strokewidth => 4);

$timg->Draw(primitive => 'line', points => get_2points(0,$mt+($ih-$mt-$mb)*$m1,$iw,$mt+($ih-$mt-$mb)*$m1), stroke => 'blue', strokewidth => 4);
$timg->Draw(primitive => 'line', points => get_2points(0,$mt+($ih-$mt-$mb)*$m2,$iw,$mt+($ih-$mt-$mb)*$m2), stroke => 'blue', strokewidth => 4);
$timg->Draw(primitive => 'line', points => get_2points($ml+($iw-$ml-$mr)*$m3,0,$ml+($iw-$ml-$mr)*$m3,$ih), stroke => 'blue', strokewidth => 4);
$timg->Draw(primitive => 'line', points => get_2points($ml+($iw-$ml-$mr)*$m4,0,$ml+($iw-$ml-$mr)*$m4,$ih), stroke => 'blue', strokewidth => 4);

$simg->Modulate(brightness => 75);
$simg->Composite(image => $mimg, compose => 'Over');
$simg->Composite(image => $timg, compose => 'Over');
$simg->Extent(x => -$td*2, y => -$td*2, width => $iw+$td*2+400, height => $ih+$td*2+100, background => '#cccccc');

foreach my $i (0..int($iw/$td)) {
    my ($ix, $iy) = ($i*$td+$td*2, $td);
    $simg->Annotate(text => $i, font => 'Curier', pointsize => $td/2, x => $ix, y => $iy, fill => 'black');
}
foreach my $j (0..int($ih/$td)) {
    my ($jx, $jy) = ($td, $j*$td+$td*2);
    $simg->Annotate(text => $j, font => 'Curier', pointsize => $td/2, x => $jx, y => $jy, fill => 'black');
}
$simg->Annotate(text => $m1, font => 'Curier', pointsize => 30, x=>$iw+$td*2+10, y => $mt+($ih-$mt-$mb)*$m1+$td*2, fill => 'blue');
$simg->Annotate(text => $m2, font => 'Curier', pointsize => 30, x=>$iw+$td*2+10, y => $mt+($ih-$mt-$mb)*$m2+$td*2, fill => 'blue');
$simg->Annotate(text => $m3, font => 'Curier', pointsize => 30, x=>$ml+($iw-$ml-$mr)*$m3+$td*2, y => $ih+$td*2+$td, fill => 'blue');
$simg->Annotate(text => $m4, font => 'Curier', pointsize => 30, x=>$ml+($iw-$ml-$mr)*$m4+$td*2, y => $ih+$td*2+$td, fill => 'blue');
$simg->Write($tmpdir.'/'.$sid.'.jpg');

$dimg->Crop(x => $cl, y => $ct, width => $iw-$cl-$cr, height => $ih-$ct-$cb);
$dimg->Write($dstdir.'/'.$sid.'.jpg');

sub distance_2points {
    my ($fx, $fy, $tx, $ty) = @_;
    my ($dx, $dy) = ($tx-$fx, $ty-$fy);
    return sqrt($dx*$dx+$dy*$dy);
}

#指定区域，不同扫描次序
sub find_point {
    my ($x, $y, $w, $h, $t, $k) = @_;
    my ($px, $py);
    #0: top->bottom left->right
    if($t == 0) {
        Y: foreach my $j ($y..$y+$h) {
            X: foreach my $i ($x..$x+$w) {
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/($#pixels) >= 0.8) {
                    ($px, $py) = ($i, $j);
                    last Y;
                }
            }
        }
    }
    #1: left->right top->bottom
    if($t == 1) {
        X: foreach my $i ($x..$x+$w) {
            Y: foreach my $j ($y..$y+$h) {            
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/($#pixels) >= 0.8) {
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
                if($psum/($#pixels) >= 0.8) {
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
                if($psum/($#pixels) >= 0.8) {
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
                if($psum/$#pixels >= 0.8) {
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
                if($psum/$#pixels >= 0.8) {
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
                if($psum/$#pixels >= 0.8) {
                    ($px, $py) = ($i, $j);
                    last Y;
                }
            }
        }
    }
    #7: left->right $bottom->top
    if($t == 7) {
        X: foreach my $i ($x..$x+$w) {
            Y: foreach my $j (reverse $y..$y+$h) {
                my @pixels = $timg->GetPixels(x => $i, y => $j, width => $k, height => $k, normalize => 'true');
                my $psum = pixels_sum(@pixels);
                if($psum/$#pixels >= 0.8) {
                    ($px, $py) = ($i, $j);
                    last X;
                }
            }
        }
    }
    return ($px, $py);
}

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
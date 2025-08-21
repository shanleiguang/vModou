#!/usr/bin/perl
#古籍扫描图左右切割
#by shanleiguang@gmail.com, 2025/08
use strict;
use warnings;

use Image::Magick;
use Getopt::Long;
use Data::Dumper;

my $tflag = '';
my $imgid = '';
my ($cc, $cl, $cr, $ct, $cb, $td) = (0.05, 20, 20, 20, 20, 50);
my $odir = 'original';

GetOptions(
    't'    => \$tflag,
    'i=s'  => \$imgid,
    'td=i' => \$td,
    'cc=f' => \$cc,
    'cl=i' => \$cl,
    'cr=i' => \$cr,
    'ct=i' => \$ct,
    'cb=i' => \$cb,
);

my %excs = ();

if(-f 'nosplit.txt') {
    open NS, '< nosplit.txt';
    while(<NS>) {
        chomp;
        s/\s|\t//g;
        $excs{$_} = 1;
    }
    close(NS);
}
#print Dumper(\%excs) and exit;

if($tflag) {
    my $timgfn = "$odir/$imgid".'.jpg';
    print "$timgfn\n";
    print "错误：未指定测试图片'-i'!\n" if(not $imgid);
    print "错误：'$timgfn'测试图片文件不存在！\n" and exit if(not -f $timgfn);
    print "错误：'$timgfn'测试图片在不分隔图片中！\n" and exit if(defined $excs{$imgid});
    my $timg = Image::Magick->new();
    my ($tw, $th);

    $timg->ReadImage($timgfn);
    ($tw, $th) = ($timg->Get('width'), $timg->Get('height'));
    print "$tw x $th\n";
    foreach my $i (1..int($tw/$td)) {
        $timg->Draw(primitive => 'line', points => get_2points(0,$td*$i,$tw,$td*$i), fill => 'gray');
    }
    foreach my $j (1..int($th/$td)) {
        $timg->Draw(primitive => 'line', points => get_2points($td*$j,0,$td*$j,$th), fill => 'gray');
    }
    $timg->Draw(primitive => 'line', points => get_2points($tw/2-$tw*$cc/2,0,$tw/2-$tw*$cc/2,$th), fill => 'red', stroke => 'red', strokewidth => 5);
    $timg->Draw(primitive => 'line', points => get_2points($tw/2+$tw*$cc/2,0,$tw/2+$tw*$cc/2,$th), fill => 'red', stroke => 'red', strokewidth => 5);
    $timg->Draw(primitive => 'line', points => get_2points($cl,0,$cl,$th), fill => 'red', stroke => 'red', strokewidth => 5);
    $timg->Draw(primitive => 'line', points => get_2points($tw-$cr,0,$tw-$cr,$th), fill => 'red', stroke => 'red', strokewidth => 5);
    $timg->Draw(primitive => 'line', points => get_2points(0,$ct,$tw,$ct), fill => 'red', stroke => 'red', strokewidth => 5);
    $timg->Draw(primitive => 'line', points => get_2points(0,$th-$cb,$tw,$th-$cb), fill => 'red', stroke => 'red', strokewidth => 5);
    $timg->Write("test/$imgid".'.jpg');
    exit;
}

opendir ODIR, $odir;
foreach my $fn (sort readdir(ODIR)) {
    next if($fn !~ m/\.jpg$/);
    last if($fn =~ m/^-0059/);
    next if(defined $excs{(split /\./, $fn)[0]});

    my $oimg = Image::Magick->new();
    my $limg = Image::Magick->new();
    my $rimg = Image::Magick->new();
    my ($ow, $oh);

    $oimg->ReadImage("$odir/$fn");
    $limg = $oimg->Clone();
    $rimg = $oimg->Clone();
    ($ow, $oh) = ($oimg->Get('width'), $oimg->Get('height'));
    $limg->Crop(x => $cl, y => $ct, width => ($ow*(1-$cc))/2-$cl, height => $oh-$ct-$cb);
    $rimg->Crop(x => $ow*(1+$cc)/2, y => $ct, width => ($ow*(1-$cc))/2-$cr, height => $oh-$ct-$cb);
    $limg->Write('src/'.(split /\./, $fn)[0].'_0.jpg');
    $rimg->Write('src/'.(split /\./, $fn)[0].'_1.jpg');
}
closedir(ODIR);

sub get_2points {
    my ($x1, $y1, $x2, $y2) = @_;
    return "$x1,$y1 $x2,$y2";
}
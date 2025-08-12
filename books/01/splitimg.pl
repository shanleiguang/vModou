#!/usr/bin/perl
use strict;
use warnings;
use Image::Magick;

my $center_pct = 0.05;
my ($cl, $cr, $ct, $cb) = (30,0,20,20);
my @excs = (
    '0000', '0001',
    '0059', '0060', '0061', '0062',
    '0114', '0115', '0116', '0117',
    '0169', '0170', '0171', '0172',
    '0224', '0225', '0226', '0227',
    '0279', '0280', '0281', '0282',
    '0334', '0335'
);

opendir SDIR, 'src';
O: foreach my $fn (sort readdir(SDIR)) {
    next if($fn !~ m/\.jpg$/);
    last if($fn =~ m/^-0059/);
    E: foreach my $e (@excs) {
        next O if($fn =~ m/^-$e/);
    }
    my $simg = Image::Magick->new();
    my $limg = Image::Magick->new();
    my $rimg = Image::Magick->new();
    my ($sw, $sh);

    $simg->ReadImage("src/$fn");
    $limg = $simg->Clone();
    $rimg = $simg->Clone();
    ($sw, $sh) = ($simg->Get('width'), $simg->Get('height'));
    $limg->Crop(x => $cl, y => $ct, width => ($sw*(1-$center_pct))/2-$cl, height => $sh-$ct-$cb);
    $rimg->Crop(x => $sw*(1+$center_pct)/2, y => $ct, width => ($sw*(1-$center_pct))/2-$cr, height => $sh-$ct-$cb);
    $limg->Write('crop/'.(split /\./, $fn)[0].'_0.jpg');
    $rimg->Write('crop/'.(split /\./, $fn)[0].'_1.jpg');
}
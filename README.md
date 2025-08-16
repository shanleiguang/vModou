


## vModou is 兀雨墨斗古籍刻本掃描圖像變形糾正工具

![image](https://github.com/shanleiguang/vModou/blob/main/images/000.png)

- 啟發：墨斗是中國木工傳統行業的常用工具，通常用來打線和測量。圖像變形糾正，正是基於一系列測量得到適當的變形參數，然後交給計算機圖像算法執行。受此啟發，作此工具。
- 思路：針對古籍刻本掃描圖像的特點，關鍵是找對四角頂點，頂點之間就是邊長，以其中一個頂點為參照，按照邊長不變條件，通過勾股定理計算變形後新頂點座標，然後做新舊頂點之間的線型變形。
- 技巧：一是受墨斗測量應用的啟發，先打好輔助線，限定四角頂點掃描區域，儘量減少掃描干擾，使程序能夠精準的掃描得到可選頂點。二是變形方法的前後次序將非常影響最終效果，應避免後一操作影響前一操作的情況，那會帶來不必要困擾和糾結，本工具採用的次序是：四頂點變为矩阵 -> 對变形后顶点坐标手工微调 -> 图像长宽比例微调 -> 裁切四边变形产生的黑边，這裡的每一步都對其前面變形的整體效果很少甚至沒有影響。
- 步驟：調整輔助線參數 - 打輔助線 - 掃描確定頂點 - 調整變形參數 - 觀察變形效果 - 優化變形參數 - 裁切四邊。
- 優點：一是所有技術參數均可控，變形過程簡單明瞭，不靠感覺，減少糾結；二是命令行工具省手腕，緩解長期PS的鼠標手；三是看到歪歪斜斜的掃描圖像變規整，很解壓不是嗎。

## 舉個例子

```
perl vmodou.pl -b 01 -i -0008_0  
读取预设参数'books/01/vmodou.cfg'，命令行参数优先！  
================================================================================  
    vModou v1.0，兀雨墨斗古籍扫描图变形纠正工具  
	作者：GitHub@shanleiguang，小红书@兀雨书屋，2025  
================================================================================  
  原扫描图：books/01/src/-0008_0.jpg  
  测试模式：是	测试线间距：50  
  顶点扫描像素块尺寸：2 x 2	顶点扫描像素块有效像素门限：0.8  
  内容区域参数：-ml 20 -mr 20 -mt 500 -mb 200  
  内容剔除参数：-m1 0.1 -m2 0.9 -m3 0.1 -m4 0.9  
  四角顶点序号：-pa 0 -pb 0 -pc 0 -pd 0，0-自动选择  
  顶点变形微调：-da 0,0 -db 0,0 -dc 0,0 -dd 0,0  
  变形参考顶点：-sp A	变形方法参数：Affine  
  变形拉伸参数：-sw 1 -sh 1	旋转角度：-sd 0  
  最终裁切参数：-cl 0 -cr 0 -ct 0, -cb 0  
================================================================================  
读取原始扫描图'books/01/src/-0008_0.jpg'（1512 x 2959）  
生成测试图'books/01/tmp/-0008_0.jpg'！
```

![image](https://github.com/shanleiguang/vModou/blob/main/images/001.png)

```
perl vmodou.pl -b 01 -i -0008_0 -t 0
```

![image](https://github.com/shanleiguang/vModou/blob/main/images/002.png)

```
perl vmodou.pl -b 01 -i -0008_0 -t 0 -mt 560 -m2 0.94
```
![image](https://github.com/shanleiguang/vModou/blob/main/images/003.png)

```
perl vmodou.pl -b 01 -i -0008_0 -t 0 -mt 560 -m2 0.94 -pa 1 -pc 2
```

![image](https://github.com/shanleiguang/vModou/blob/main/images/004.png)

```
perl vmodou.pl -b 01 -i -0008_0 -t 0 -mt 560 -m2 0.94 -pa 1 -pc 2 -cl 40 -cr 10 -cb 20
```

![image](https://github.com/shanleiguang/vModou/blob/main/images/005.png)

## 赞助支持 Sponsorship
![image](https://github.com/shanleiguang/vRain/blob/main/sponsor_new.png)  
- 本工具是Private開源項目，這裡只是預覽。
- 目前已基本可用，但仍有很大提升空間，因此僅面向訂閱者開放， 贊助後我將邀請您訪問該項目，一個月後續訂可通過Sponsor按鈕或該私有項目頁面提示。較Pbulic項目Private項目有以下不同：


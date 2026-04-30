
deep

operation            |              mp3 |         mp3-virt |              ct
---------------------|------------------|------------------|----------------
root?                |  4,856,548.0 i/s |  4,797,540.5 i/s | 3,781,488.4 i/s
ancestor_ids         |    553,509.8 i/s |    542,704.0 i/s |       886.6 i/s
ancestor_ids cached  | 36,199,451.2 i/s | 35,644,898.9 i/s |       797.9 i/s
parent               |      9,673.5 i/s |      9,285.8 i/s |     8,837.3 i/s
parent cached        |      9,664.8 i/s |      9,527.2 i/s | 3,553,826.3 i/s
children             |      9,488.6 i/s |      9,694.1 i/s |     6,595.8 i/s
children cached      |      9,333.6 i/s |  3,209,879.4 i/s | 3,140,993.3 i/s
ancestors            |      3,992.1 i/s |      1,043.8 i/s |       794.7 i/s
ancestors cached     |      4,030.6 i/s |      1,018.3 i/s |       732.8 i/s
descendants          |      5,087.2 i/s |      1,497.9 i/s |       677.6 i/s
descendants cached   |      5,095.1 i/s |      4,978.0 i/s |       639.0 i/s
roots                |      8,983.7 i/s |      9,217.8 i/s |     8,180.3 i/s
leaf?                |      9,610.7 i/s |      9,689.7 i/s |     8,004.2 i/s
arrange              |        276.4 i/s |        280.5 i/s |       174.8 i/s
4.each_parent        |      2,943.8 i/s |      2,878.8 i/s |     2,829.9 i/s
4.each_children      |      3,106.7 i/s |      2,797.9 i/s |     1,739.0 i/s
4.descendants        |      1,625.0 i/s |      1,654.5 i/s |     1,144.4 i/s
4.includes(:parent)  |                  |      3,832.0 i/s |     3,863.2 i/s
4.preload(:children) |                  |      3,566.1 i/s |     3,031.8 i/s

mixed

operation            |              mp3 |         mp3-virt |              ct
---------------------|------------------|------------------|----------------
root?                |  4,851,037.0 i/s |  4,835,236.1 i/s | 3,752,446.2 i/s
ancestor_ids         |  2,952,293.2 i/s |  2,933,890.7 i/s |     3,055.1 i/s
ancestor_ids cached  | 36,710,841.8 i/s | 36,472,003.0 i/s |     4,693.5 i/s
parent               |      9,649.9 i/s |      9,596.7 i/s |     8,923.7 i/s
parent cached        |      9,650.1 i/s |      9,643.1 i/s | 3,546,602.3 i/s
children             |      9,293.9 i/s |      9,182.0 i/s |     5,995.5 i/s
children cached      |      9,297.6 i/s |  3,214,993.9 i/s | 3,123,708.3 i/s
ancestors            |      8,533.3 i/s |      8,397.5 i/s |     1,042.7 i/s
ancestors cached     |      8,535.9 i/s |      8,265.2 i/s |       992.2 i/s
descendants          |      6,978.9 i/s |      6,780.1 i/s |       819.9 i/s
descendants cached   |      6,678.6 i/s |      6,731.9 i/s |       772.2 i/s
roots                |      8,760.8 i/s |      8,894.2 i/s |     8,538.7 i/s
leaf?                |      9,968.4 i/s |      9,504.6 i/s |     8,225.3 i/s
arrange              |        276.4 i/s |        274.7 i/s |       165.0 i/s
4.each_parent        |      1,773.5 i/s |      1,728.1 i/s |     1,699.5 i/s
4.each_children      |      1,743.5 i/s |      1,460.3 i/s |       851.6 i/s
4.descendants        |      1,366.6 i/s |      1,352.4 i/s |     1,014.5 i/s
4.includes(:parent)  |                  |      3,551.4 i/s |     3,711.3 i/s
4.preload(:children) |                  |      2,180.2 i/s |     1,594.6 i/s

wide

operation            |              mp3 |         mp3-virt |              ct
---------------------|------------------|------------------|----------------
root?                |  4,991,070.1 i/s |  4,975,515.8 i/s | 3,835,916.3 i/s
ancestor_ids         |  3,045,556.1 i/s |  2,946,700.3 i/s |     3,254.1 i/s
ancestor_ids cached  | 36,846,218.5 i/s | 34,188,706.1 i/s |     4,905.8 i/s
parent               |      9,741.1 i/s |      9,535.8 i/s |     9,205.6 i/s
parent cached        |      9,680.8 i/s |      9,609.2 i/s | 3,694,273.0 i/s
children             |      9,042.8 i/s |      8,737.0 i/s |     6,046.9 i/s
children cached      |      9,270.4 i/s |  3,251,747.9 i/s | 3,270,480.9 i/s
ancestors            |      8,796.5 i/s |      8,697.5 i/s |     2,480.3 i/s
ancestors cached     |      8,807.3 i/s |      8,681.7 i/s |     4,500.1 i/s
descendants          |      7,393.4 i/s |      6,965.3 i/s |     5,078.9 i/s
descendants cached   |      7,401.7 i/s |      7,264.0 i/s |     4,987.4 i/s
roots                |      9,341.5 i/s |      9,336.3 i/s |     8,616.4 i/s
leaf?                |     10,118.9 i/s |      9,589.5 i/s |     8,029.6 i/s
arrange              |        278.1 i/s |        284.7 i/s |       169.7 i/s
4.each_parent        |      1,766.4 i/s |      1,775.0 i/s |     1,720.7 i/s
4.each_children      |      1,712.3 i/s |      1,424.0 i/s |       825.4 i/s
4.descendants        |      1,452.9 i/s |      1,441.0 i/s |       218.9 i/s
4.includes(:parent)  |                  |      3,616.9 i/s |     3,742.3 i/s
4.preload(:children) |                  |      1,709.6 i/s |     1,210.1 i/s

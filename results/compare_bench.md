
deep

operation            |         ancestry |   ancestry+assoc |    closure_tree
---------------------|------------------|------------------|----------------
root?                |  [32m4,911,720.5 i/s[0m |  [32m4,976,470.4 i/s[0m | [31m3,867,353.9 i/s[0m
ancestor_ids         |    [32m567,189.9 i/s[0m |    [32m567,651.3 i/s[0m |     [31m1,130.2 i/s[0m
ancestor_ids cached  | [32m36,552,610.8 i/s[0m | [32m36,927,791.6 i/s[0m |     [31m1,106.1 i/s[0m
parent               |     [32m10,049.8 i/s[0m |      [32m9,960.0 i/s[0m |     [31m9,338.4 i/s[0m
children             |      [32m9,787.7 i/s[0m |     [32m10,088.8 i/s[0m |     [31m6,999.8 i/s[0m
ancestors            |      [32m4,214.4 i/s[0m |      [31m1,264.6 i/s[0m |     [31m1,091.8 i/s[0m
descendants          |      [32m5,372.0 i/s[0m |      [;0m1,623.0 i/s[0m |     [31m1,001.6 i/s[0m
roots                |      [32m9,638.3 i/s[0m |      [32m9,647.0 i/s[0m |     [31m8,881.2 i/s[0m
leaf?                |     [32m10,299.3 i/s[0m |      [;0m9,934.7 i/s[0m |     [31m8,503.4 i/s[0m
arrange              |        [32m288.3 i/s[0m |        [32m289.1 i/s[0m |       [31m197.5 i/s[0m
4.descendants        |      [32m1,475.5 i/s[0m |      [32m1,797.7 i/s[0m |     [32m1,279.8 i/s[0m
children cached      |                  |  [32m3,325,824.6 i/s[0m | [31m3,245,207.7 i/s[0m
descendants cached   |                  |      [32m4,891.4 i/s[0m |     [31m1,012.9 i/s[0m
4.preload(:children) |                  |      [32m3,661.3 i/s[0m |     [31m3,160.0 i/s[0m

mixed

operation            |         ancestry |   ancestry+assoc |    closure_tree
---------------------|------------------|------------------|----------------
root?                |  [32m4,945,675.4 i/s[0m |  [32m5,025,309.6 i/s[0m | [31m3,898,478.5 i/s[0m
ancestor_ids         |  [32m3,042,930.0 i/s[0m |  [32m3,000,069.0 i/s[0m |     [31m1,350.6 i/s[0m
ancestor_ids cached  | [32m36,893,920.6 i/s[0m | [32m37,377,744.9 i/s[0m |     [31m1,259.3 i/s[0m
parent               |     [32m10,001.1 i/s[0m |      [32m9,898.3 i/s[0m |     [31m9,259.9 i/s[0m
children             |      [32m9,715.3 i/s[0m |      [32m9,533.4 i/s[0m |     [31m6,740.6 i/s[0m
ancestors            |      [32m8,905.7 i/s[0m |      [32m8,895.6 i/s[0m |     [31m1,190.8 i/s[0m
descendants          |      [32m7,259.2 i/s[0m |      [32m7,262.5 i/s[0m |     [31m1,075.5 i/s[0m
roots                |      [32m9,614.3 i/s[0m |      [32m9,622.8 i/s[0m |     [31m8,888.3 i/s[0m
leaf?                |     [32m10,572.3 i/s[0m |      [;0m9,948.9 i/s[0m |     [31m8,503.1 i/s[0m
arrange              |        [32m290.2 i/s[0m |        [32m289.1 i/s[0m |       [31m187.1 i/s[0m
4.descendants        |      [32m1,448.3 i/s[0m |      [32m1,450.8 i/s[0m |       [31m263.9 i/s[0m
children cached      |                  |  [32m3,306,436.7 i/s[0m | [32m3,303,517.5 i/s[0m
descendants cached   |                  |      [32m7,289.0 i/s[0m |     [31m1,043.1 i/s[0m
4.preload(:children) |                  |      [32m1,813.9 i/s[0m |       [31m751.4 i/s[0m

wide

operation            |         ancestry |   ancestry+assoc |    closure_tree
---------------------|------------------|------------------|----------------
root?                |  [32m4,993,853.2 i/s[0m |  [32m5,042,653.7 i/s[0m | [31m3,868,700.1 i/s[0m
ancestor_ids         |  [32m3,059,305.1 i/s[0m |  [32m3,054,838.1 i/s[0m |     [31m4,894.0 i/s[0m
ancestor_ids cached  | [32m36,925,294.2 i/s[0m | [32m36,553,885.5 i/s[0m |     [31m4,969.2 i/s[0m
parent               |      [32m9,920.3 i/s[0m |      [32m9,871.5 i/s[0m |     [31m9,300.3 i/s[0m
children             |      [32m9,432.3 i/s[0m |      [;0m8,830.1 i/s[0m |     [31m6,254.9 i/s[0m
ancestors            |      [32m8,806.7 i/s[0m |      [32m8,805.0 i/s[0m |     [31m1,251.1 i/s[0m
descendants          |      [32m7,454.2 i/s[0m |      [32m7,448.4 i/s[0m |     [31m1,418.4 i/s[0m
roots                |      [32m9,612.5 i/s[0m |      [32m9,607.7 i/s[0m |     [31m8,894.0 i/s[0m
leaf?                |     [32m10,588.1 i/s[0m |     [;0m10,060.0 i/s[0m |     [31m8,502.1 i/s[0m
arrange              |        [32m287.7 i/s[0m |        [32m288.2 i/s[0m |       [31m188.8 i/s[0m
4.descendants        |      [32m1,475.1 i/s[0m |      [32m1,479.3 i/s[0m |       [31m319.5 i/s[0m
children cached      |                  |  [32m3,262,188.1 i/s[0m | [32m3,280,813.4 i/s[0m
descendants cached   |                  |      [32m7,449.0 i/s[0m |     [31m1,422.5 i/s[0m
4.preload(:children) |                  |      [32m1,458.5 i/s[0m |       [31m777.9 i/s[0m

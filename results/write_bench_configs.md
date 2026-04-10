
deep pg

operation      |         mp1 |         mp2 |         mp3 |   mp3-depth |  mp3-parent |    mp3-virt |       ltree |       array
---------------|-------------|-------------|-------------|-------------|-------------|-------------|-------------|------------
build tree     |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs
create+destroy | 1,580.4 i/s | 1,566.1 i/s | 1,586.6 i/s | 1,525.1 i/s | 1,481.3 i/s | 1,520.7 i/s | 1,509.3 i/s | 1,279.6 i/s
move subtree   | 1,235.4 i/s | 1,248.9 i/s | 1,270.0 i/s | 1,184.0 i/s | 1,118.6 i/s | 1,203.6 i/s | 1,160.3 i/s |   877.8 i/s
parent=        | 1,196.2 i/s | 1,253.3 i/s | 1,254.2 i/s | 1,172.7 i/s | 1,114.9 i/s | 1,179.5 i/s | 1,152.0 i/s |   873.3 i/s
parent_id=     |   943.1 i/s |   972.5 i/s |   987.3 i/s |   926.1 i/s |   891.2 i/s |   927.6 i/s |   904.8 i/s |   723.9 i/s

mixed pg

operation      |         mp1 |         mp2 |         mp3 |   mp3-depth |  mp3-parent |    mp3-virt |       ltree |       array
---------------|-------------|-------------|-------------|-------------|-------------|-------------|-------------|------------
build tree     |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs |      3 objs
create+destroy | 1,563.9 i/s | 1,608.2 i/s | 1,605.1 i/s | 1,549.9 i/s | 1,507.4 i/s | 1,522.3 i/s | 1,551.0 i/s | 1,400.1 i/s
move subtree   | 1,225.2 i/s | 1,273.6 i/s | 1,289.3 i/s | 1,203.6 i/s | 1,141.9 i/s | 1,196.8 i/s | 1,230.1 i/s | 1,023.2 i/s
parent=        | 1,228.6 i/s | 1,282.1 i/s | 1,270.9 i/s | 1,200.7 i/s | 1,146.9 i/s | 1,192.9 i/s | 1,229.9 i/s | 1,012.5 i/s
parent_id=     |   958.4 i/s |   991.6 i/s |   996.0 i/s |   944.8 i/s |   912.5 i/s |   939.4 i/s |   967.9 i/s |   817.6 i/s

wide pg

operation      |         mp1 |         mp2 |         mp3 |   mp3-depth |  mp3-parent |    mp3-virt |       ltree |       array
---------------|-------------|-------------|-------------|-------------|-------------|-------------|-------------|------------
build tree     |      4 objs |      4 objs |      4 objs |      4 objs |      4 objs |      4 objs |      4 objs |      4 objs
create+destroy | 1,614.4 i/s | 1,626.8 i/s | 1,593.6 i/s | 1,568.8 i/s | 1,491.1 i/s | 1,549.0 i/s | 1,567.8 i/s | 1,403.4 i/s
move subtree   | 1,285.6 i/s | 1,289.7 i/s | 1,279.0 i/s | 1,260.0 i/s | 1,150.6 i/s | 1,236.8 i/s | 1,247.8 i/s | 1,018.3 i/s
parent=        | 1,293.5 i/s | 1,262.0 i/s | 1,285.0 i/s | 1,251.5 i/s | 1,156.8 i/s | 1,232.6 i/s | 1,236.3 i/s | 1,005.9 i/s
parent_id=     | 1,002.9 i/s |   990.5 i/s |   993.3 i/s |   967.8 i/s |   919.3 i/s |   969.3 i/s |   969.2 i/s |   812.0 i/s

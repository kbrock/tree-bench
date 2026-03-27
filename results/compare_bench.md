# ancestry vs closure_tree

### deep (ips)

| operation            | ancestry      | ancestry+assoc | closure_tree |
| -------------------- | ------------: | -------------: | -----------: |
| root?                | **5,006,001** |    4,994,571.1 |  3,868,185.2 |
| ancestor_ids         | **572,251.7** |      567,358.9 |      1,192.8 |
| parent               |       9,765.1 |      **9,863** |      9,208.3 |
| children             |       9,011.3 |    **9,861.8** |      6,998.8 |
| ancestors            |   **4,028.8** |        1,424.6 |      1,034.5 |
| descendants          |   **5,188.1** |        1,495.8 |        928.1 |
| roots                |       9,054.5 |    **9,351.8** |      8,620.9 |
| leaf?                |         9,942 |   **10,021.6** |      8,297.3 |
| ancestor_ids cached  |  38,293,025.4 | **38,654,912** |      1,193.3 |
| descendants cached   |               |    **3,198.2** |      1,017.1 |
| 4.preload(:children) |               |    **3,660.2** |      3,025.7 |

### deep (queries)

| operation           | ancestry | ancestry+assoc | closure_tree |
| ------------------- | -------: | -------------: | -----------: |
| ancestor_ids        |    **0** |              0 |            1 |
| ancestor_ids cached |    **0** |              0 |            1 |
| 4.descendants       |        3 |              3 |        **2** |

### deep (rows)

| operation     | closure_tree | ancestry | ancestry+assoc |
| ------------- | -----------: | -------: | -------------: |
| 4.descendants |       **73** |       75 |             75 |

### mixed (ips)

| operation            | ancestry        | ancestry+assoc   | closure_tree |
| -------------------- | --------------: | ---------------: | -----------: |
| root?                | **5,033,369.6** |      4,919,008.3 |  3,873,787.3 |
| ancestor_ids         | **2,944,779.9** |      2,908,789.6 |      1,346.4 |
| parent               |     **9,894.6** |          9,817.4 |      9,147.8 |
| children             |     **9,534.1** |          9,462.6 |      6,384.8 |
| ancestors            |         8,782.1 |      **8,986.6** |      2,983.6 |
| descendants          |         7,168.3 |      **7,397.9** |      4,127.6 |
| roots                |         9,072.2 |      **9,519.1** |      8,694.4 |
| leaf?                |    **10,248.7** |         10,109.7 |      8,359.6 |
| arrange              |           275.8 |        **279.2** |        190.2 |
| ancestor_ids cached  |    37,631,568.4 | **37,812,441.2** |      4,636.8 |
| 4.descendants        |           1,389 |      **1,431.2** |        291.3 |
| children cached      |                 |  **3,324,385.2** |  3,232,202.4 |
| descendants cached   |                 |        **7,399** |      4,133.6 |
| 4.preload(:children) |                 |      **2,143.2** |      1,549.3 |

### mixed (queries)

| operation           | ancestry | ancestry+assoc | closure_tree |
| ------------------- | -------: | -------------: | -----------: |
| ancestor_ids        |    **0** |              0 |            1 |
| ancestor_ids cached |    **0** |              0 |            1 |
| 4.descendants       |        5 |              5 |        **4** |

### mixed (rows)

| operation     | closure_tree | ancestry | ancestry+assoc |
| ------------- | -----------: | -------: | -------------: |
| 4.descendants |       **36** |       40 |             40 |

### wide (ips)

| operation            | ancestry         | ancestry+assoc  | closure_tree |
| -------------------- | ---------------: | --------------: | -----------: |
| root?                |  **5,118,718.9** |     5,100,587.7 |  3,927,981.6 |
| ancestor_ids         |      3,058,179.3 | **3,063,366.2** |      1,255.4 |
| parent               |      **9,974.8** |         9,962.8 |      9,333.1 |
| children             |      **9,196.8** |         8,778.9 |      6,358.5 |
| ancestors            |          8,792.9 |     **9,000.6** |      1,259.8 |
| descendants          |          7,477.3 |     **7,487.4** |      4,285.9 |
| roots                |          9,351.3 |       **9,457** |      9,020.3 |
| leaf?                |     **10,350.5** |        10,097.7 |      8,609.6 |
| arrange              |            276.5 |       **277.6** |        185.1 |
| ancestor_ids cached  | **38,632,194.1** |    37,764,356.1 |      4,778.2 |
| 4.descendants        |      **1,461.6** |         1,423.3 |        273.7 |
| descendants cached   |                  |     **7,586.6** |      5,317.9 |
| 4.preload(:children) |                  |     **1,687.2** |        631.9 |

### wide (queries)

| operation           | ancestry | ancestry+assoc | closure_tree |
| ------------------- | -------: | -------------: | -----------: |
| ancestor_ids        |    **0** |              0 |            1 |
| ancestor_ids cached |    **0** |              0 |            1 |
| 4.descendants       |        5 |              5 |        **4** |

### wide (rows)

| operation     | closure_tree | ancestry | ancestry+assoc |
| ------------- | -----------: | -------: | -------------: |
| 4.descendants |       **20** |       24 |             24 |


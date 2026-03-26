# ancestry vs closure_tree

### deep (ips)

| operation    | ancestry      | closure_tree |
| ------------ | ------------: | -----------: |
| root?        | **4,619,328** |    3,944,179 |
| ancestor_ids | **594,656.1** |      1,204.2 |
| parent       |  **10,189.4** |      9,263.8 |
| children     |  **10,238.2** |      7,055.9 |
| ancestors    |   **4,272.3** |      3,928.6 |
| descendants  |   **5,174.2** |      2,730.1 |
| roots        |  **10,648.5** |        8,938 |
| leaf?        |  **10,263.4** |      8,393.4 |
| arrange      |     **275.7** |        193.4 |

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

| operation    | ancestry        | closure_tree |
| ------------ | --------------: | -----------: |
| root?        | **4,620,852.6** |  4,010,146.9 |
| ancestor_ids | **3,148,183.9** |      1,160.1 |
| parent       |    **10,047.5** |      9,291.5 |
| children     |    **10,082.3** |      6,843.9 |
| ancestors    |     **8,998.8** |      4,765.6 |
| descendants  |     **6,749.1** |      4,289.5 |
| roots        |    **10,702.6** |      8,894.7 |
| leaf?        |      **10,509** |      8,207.2 |
| arrange      |       **276.7** |        195.2 |

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

| operation    | ancestry        | closure_tree |
| ------------ | --------------: | -----------: |
| root?        | **4,677,234.4** |    3,951,896 |
| ancestor_ids | **3,204,862.7** |      4,491.1 |
| parent       |    **10,067.5** |        9,224 |
| children     |     **9,792.7** |      6,292.8 |
| ancestors    |     **8,983.9** |      4,765.1 |
| descendants  |     **6,959.9** |      5,148.1 |
| roots        |    **10,779.4** |      8,878.7 |
| leaf?        |    **10,484.5** |      8,204.6 |
| arrange      |       **277.1** |        197.4 |

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


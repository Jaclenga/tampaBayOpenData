# List bundled ArcGIS publisher configurations

Returns the package's Tampa Bay publisher configurations without a
network request. Each entry provides an ArcGIS organization ID and
sharing REST root. Its `verified` date checks publisher identity, not
every layer's contents or reuse terms. To scan another portal, pass its
sharing REST URL to
[`tbod_discover()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_discover.md).

## Usage

``` r
tbod_list_portals()
```

## Value

A tibble with `id` (the discovery selector), `root`, `org_id`,
`publisher`, `jurisdiction`, `website`, `verified` (a Date),
`metadata_url`, and `evidence_url`. Use `id` in the `portals` argument
of
[`tbod_list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_list_datasets.md)
or
[`tbod_search_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/tbod_search_datasets.md).

## Examples

``` r
tbod_list_portals()
#> # A tibble: 6 × 9
#>   id         root  org_id publisher jurisdiction website verified   metadata_url
#>   <chr>      <chr> <chr>  <chr>     <chr>        <chr>   <date>     <chr>       
#> 1 city       http… IbNXl… City of … tampa        https:… 2026-10-02 https://tam…
#> 2 tbrpc      http… RgIBb… Tampa Ba… tampa-bay    https:… 2026-10-02 https://www…
#> 3 stpete     http… 9qPLj… City of … stpete       https:… 2026-10-02 https://csp…
#> 4 clearwater http… 3GsNo… City of … clearwater   https:… 2026-10-02 https://cit…
#> 5 hillsboro… http… apTfC… Hillsbor… hillsborough https:… 2026-10-02 https://hil…
#> 6 pinellas   http… f5HgU… Pinellas… pinellas     https:… 2026-10-02 https://pin…
#> # ℹ 1 more variable: evidence_url <chr>
```

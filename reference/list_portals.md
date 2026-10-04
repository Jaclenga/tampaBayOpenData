# List the configured public ArcGIS publishers

Reads the bundled publisher registry without network requests. Each
publisher supplies one organization ID and sharing API root to the same
discovery and retrieval code. The `verified` date records an identity
check against public organization metadata and official publisher
evidence; it does not validate every layer, its contents, or its reuse
terms. Layer provenance distinguishes discovered services from the
package's checked dataset registry.

## Usage

``` r
list_portals()
```

## Value

A tibble with `id` (the discovery selector), `root`, `org_id`,
`publisher`, `jurisdiction`, `website`, `verified` (a Date),
`metadata_url`, and `evidence_url`. Use `id` values in the `portals`
argument of
[`list_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/list_datasets.md)
or
[`search_datasets()`](https://jaclenga.github.io/tampaBayOpenData/reference/search_datasets.md).

## Examples

``` r
list_portals()
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

# {{ .Title }}

{{- range .Data.Pages.GroupByDate "2006" }}

## {{ .Key }}

{{- range .Pages }}

- [{{ .Title }}]({{ .RelPermalink }}index.md)
{{- end }}
{{- end }}

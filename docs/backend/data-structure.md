# Data structure

## JSON normalization

From Admin UI when selecting a JSON field:
> In order to support seamlessly both application/json and, multipart/form-data, requests, the following normalization rules are applied if the json field, is a, **plain string**:  
>
> - "true" is converted to the json true
> - "false" is converted to the json false
> - "null" is converted to the json null
> - "[1,2,3]" is converted to the json [1,2,3]
> - "{"a":1,"b":2}" is converted to the json {"a":1,"b":2}
> - numeric strings are converted to json number
> - double quoted strings are left as they are (aka. without normalizations)
> - any other string (empty string too) is double quoted.
>
> Alternatively, if you want to avoid the string value normalizations, you can wrap your, data inside an object, eg. `{"data": anything}`

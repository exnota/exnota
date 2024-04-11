// Named pb_file because 'file' seems to be a keyword or standard lib package
// (there were lint errors).
package pb_file

import (
	"path"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/models"
)

func Path(app core.App, record *models.Record, filename string) string {
	return path.Join(app.DataDir(), core.LocalStorageDirName, record.BaseFilesPath(), filename)
}

// Collection can be ID or name.
func Url(filename string, collection string, recordId string, app core.App) string {
	appUrl := app.Settings().Meta.AppUrl
	return appUrl + "/api/files/" + collection + "/" + recordId + "/" + filename
}

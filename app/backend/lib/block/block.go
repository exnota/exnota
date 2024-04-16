// Shared types between domains.

package block

const (
	CollectionBlock = "block"
)

// At time of writing, Property types are not used but have been included as an
// idea for future future implementation.

type PropertyType string

const (
	PropertyTypeUrl    PropertyType = "url"
	PropertyTypeSelect PropertyType = "select"
	PropertyTypeText   PropertyType = "text"
)

// A custom property configured by a user.
type UserProperty struct {
	ID   string
	Name string
	User string
	Type PropertyType

	// Config for property type
	Select []SelectOption
}

type SelectOption struct {
	OptionId string
	Name     string
	Color    string
}

// The selected value for a user property.
type UserPropertyValue struct {
	UserPropertyId string
	Type           PropertyType

	// One of these will be set
	URL    string
	Select []SelectOption
	Text   string //[]RichText
}

type UserPropertyValues map[string]UserPropertyValue

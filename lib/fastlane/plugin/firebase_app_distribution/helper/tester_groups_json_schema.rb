GROUPS_JSON_SCHEMA = {
  "type" => "object",
  "properties" => {
    "groups" => {
      "type" => "array",
      "items" => {
        "type" => "object",
        "properties" => {
          "alias" => {
            "type" => "string"
          },
          "displayName" => {
            "type" => "string"
          },
          "testers" => {
            "type" => "array",
            "items" => {
              "type" => "string",
              "format" => "email"
            }
          }
        },
        "required" => ["alias", "displayName", "testers"]
      }
    }
  },
  "required" => ["groups"]
}

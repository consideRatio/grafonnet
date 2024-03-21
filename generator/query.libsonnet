local a = import 'github.com/crdsonnet/astsonnet/main.libsonnet';
local crdsonnet = import 'github.com/crdsonnet/crdsonnet/crdsonnet/main.libsonnet';
local d = import 'github.com/jsonnet-libs/docsonnet/doc-util/main.libsonnet';

local refactor = import './refactor.libsonnet';
local utils = import './utils.libsonnet';

{
  local root = self,

  render(schemas):
    local files = self.getFilesForSchemas(schemas);
    { 'query.libsonnet': root.queryIndex(files.clean) }
    + {
      [file.path]: file.content
      for type in std.objectFields(files)
      for file in files[type]
    },

  getFilesForSchemas(schemas):
    std.foldl(
      function(acc, schema)
        local title = schema.info.title;
        local raw = {
          title: title,
          path: 'raw/query/' + title + '.libsonnet',
          content: root.generateRawLib(schema),
        };
        acc +
        {
          raw+:
            (if std.member(root.hasCustom, title)
             then [raw]
             else []),
          clean+:
            (if std.member(root.hasCustom, title)
             then [{
               title: title,
               path: 'clean/query/' + title + '.libsonnet',
               content: root.generateCleanLib(schema),
             }]
             else [raw]),
        },
      schemas,
      {},
    ),

  generateRawLib(schema):
    local title = schema.info.title;
    local customSchema =
      schema + {
        components+: {
          schemas+: std.get(fixes, title, {}),
        },
      };
    local subSchema = customSchema.components.schemas[title];

    local ast =
      utils.unwrapFromCRDsonnet(
        crdsonnet.openapi.render(
          title,
          subSchema,
          customSchema,
          refactor.ASTProcessor,
          addNewFunction=false,
        ),
        title,
      );

    utils.addDoc(ast, title, 'query.').toString(),

  generateCleanLib(schema):
    local title = schema.info.title;
    local customSchema =
      schema + {
        components+: {
          schemas+: std.get(fixes, title, {}),
        },
      };
    local subSchema = customSchema.components.schemas[title];

    local ast =
      utils.unwrapFromCRDsonnet(
        crdsonnet.openapi.render(
          title,
          subSchema,
          customSchema,
          refactor.ASTProcessor,
          addNewFunction=false,
        ),
        title,
      );

    utils.addDoc(ast, title, 'query.').toString()
    + (if std.member(self.hasCustom, title)
       then
         '\n +'
         + a.parenthesis.new(
           a.import_statement.new('../../custom/query/' + title + '.libsonnet'),
         ).toString()
       else ''),

  // FIXME: Some schemas follow a different structure,  temporarily covering for this.
  local fixes = {
    [utils.formatSchemaName('CloudWatchDataQuery')]: {
      [utils.formatSchemaName('CloudWatchDataQuery')]: {
        type: 'object',
        oneOf: [
          { '$ref': '#/components/schemas/CloudWatchAnnotationQuery' },
          { '$ref': '#/components/schemas/CloudWatchLogsQuery' },
          { '$ref': '#/components/schemas/CloudWatchMetricsQuery' },
        ],
      },

      QueryEditorArrayExpression+: {
        properties+: {
          // Prevent infinite recursion
          expressions+: { items: {} },
        },
      },
    },
    [utils.formatSchemaName('AzureMonitorDataQuery')]: {
      [utils.formatSchemaName('AzureMonitorDataQuery')]: {
        '$ref': '#/components/schemas/AzureMonitorQuery',
      },
    },
    [utils.formatSchemaName('TempoDataQuery')]: {
      [utils.formatSchemaName('TempoDataQuery')]: {
        '$ref': '#/components/schemas/TempoQuery',
      },
    },
    [utils.formatSchemaName('GoogleCloudMonitoringDataQuery')]: {
      [utils.formatSchemaName('GoogleCloudMonitoringDataQuery')]: {
        '$ref': '#/components/schemas/CloudMonitoringQuery',
      },
    },
    [utils.formatSchemaName('TestDataDataQuery')]: {
      [utils.formatSchemaName('TestDataDataQuery')]+: {
        properties+: {
          // `points` is an array of arrays, this renders awkwardly with CRDsonnet
          points: { type: 'array' },
        },
      },
    },
  },

  queryIndex(files):
    a.object.new(
      [
        a.field.new(
          a.string.new('#'),
          a.literal.new(  // render docsonnet as literal to avoid docsonnet dependency
            d.package.newSub(
              'query',
              'grafonnet.query'
            ),
          ),
        ),
      ]
      + [
        a.field.new(
          a.string.new(file.title),
          a.import_statement.new(file.path),
        )
        for file in files
      ]
    ).toString(),

  hasCustom: [
    'loki',
    'prometheus',
    'tempo',
  ],
}

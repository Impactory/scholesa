const { queryRef, executeQuery, validateArgsWithOptions, mutationRef, executeMutation, validateArgs } = require('firebase/data-connect');

const connectorConfig = {
  connector: 'example',
  service: 'scholesa-edu-2',
  location: 'us-central1'
};
exports.connectorConfig = connectorConfig;

const createDemoUserRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateDemoUser');
}
createDemoUserRef.operationName = 'CreateDemoUser';
exports.createDemoUserRef = createDemoUserRef;

exports.createDemoUser = function createDemoUser(dc) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dc, undefined);
  return executeMutation(createDemoUserRef(dcInstance, inputVars));
}
;

const listAllTeamsRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListAllTeams');
}
listAllTeamsRef.operationName = 'ListAllTeams';
exports.listAllTeamsRef = listAllTeamsRef;

exports.listAllTeams = function listAllTeams(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(listAllTeamsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const updatePlayerJerseyNumberRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'UpdatePlayerJerseyNumber', inputVars);
}
updatePlayerJerseyNumberRef.operationName = 'UpdatePlayerJerseyNumber';
exports.updatePlayerJerseyNumberRef = updatePlayerJerseyNumberRef;

exports.updatePlayerJerseyNumber = function updatePlayerJerseyNumber(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(updatePlayerJerseyNumberRef(dcInstance, inputVars));
}
;

const listMyTeamsRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListMyTeams');
}
listMyTeamsRef.operationName = 'ListMyTeams';
exports.listMyTeamsRef = listMyTeamsRef;

exports.listMyTeams = function listMyTeams(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(listMyTeamsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

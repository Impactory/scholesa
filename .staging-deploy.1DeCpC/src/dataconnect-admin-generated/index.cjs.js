const { validateAdminArgs } = require('firebase-admin/data-connect');

const connectorConfig = {
  connector: 'example',
  serviceId: 'scholesa-edu-2',
  location: 'us-central1'
};
exports.connectorConfig = connectorConfig;

function createDemoUser(dcOrOptions, options) {
  const { dc: dcInstance, options: inputOpts} = validateAdminArgs(connectorConfig, dcOrOptions, options, undefined);
  dcInstance.useGen(true);
  return dcInstance.executeMutation('CreateDemoUser', undefined, inputOpts);
}
exports.createDemoUser = createDemoUser;

function listAllTeams(dcOrOptions, options) {
  const { dc: dcInstance, options: inputOpts} = validateAdminArgs(connectorConfig, dcOrOptions, options, undefined);
  dcInstance.useGen(true);
  return dcInstance.executeQuery('ListAllTeams', undefined, inputOpts);
}
exports.listAllTeams = listAllTeams;

function updatePlayerJerseyNumber(dcOrVarsOrOptions, varsOrOptions, options) {
  const { dc: dcInstance, vars: inputVars, options: inputOpts} = validateAdminArgs(connectorConfig, dcOrVarsOrOptions, varsOrOptions, options, true, true);
  dcInstance.useGen(true);
  return dcInstance.executeMutation('UpdatePlayerJerseyNumber', inputVars, inputOpts);
}
exports.updatePlayerJerseyNumber = updatePlayerJerseyNumber;

function listMyTeams(dcOrOptions, options) {
  const { dc: dcInstance, options: inputOpts} = validateAdminArgs(connectorConfig, dcOrOptions, options, undefined);
  dcInstance.useGen(true);
  return dcInstance.executeQuery('ListMyTeams', undefined, inputOpts);
}
exports.listMyTeams = listMyTeams;


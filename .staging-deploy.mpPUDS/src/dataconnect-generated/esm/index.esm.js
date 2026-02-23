import { queryRef, executeQuery, mutationRef, executeMutation, validateArgs } from 'firebase/data-connect';

export const connectorConfig = {
  connector: 'example',
  service: 'scholesa-edu-2',
  location: 'us-central1'
};

export const createDemoUserRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateDemoUser');
}
createDemoUserRef.operationName = 'CreateDemoUser';

export function createDemoUser(dc) {
  return executeMutation(createDemoUserRef(dc));
}

export const listAllTeamsRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListAllTeams');
}
listAllTeamsRef.operationName = 'ListAllTeams';

export function listAllTeams(dc) {
  return executeQuery(listAllTeamsRef(dc));
}

export const updatePlayerJerseyNumberRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'UpdatePlayerJerseyNumber', inputVars);
}
updatePlayerJerseyNumberRef.operationName = 'UpdatePlayerJerseyNumber';

export function updatePlayerJerseyNumber(dcOrVars, vars) {
  return executeMutation(updatePlayerJerseyNumberRef(dcOrVars, vars));
}

export const listMyTeamsRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListMyTeams');
}
listMyTeamsRef.operationName = 'ListMyTeams';

export function listMyTeams(dc) {
  return executeQuery(listMyTeamsRef(dc));
}


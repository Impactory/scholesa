# Generated TypeScript README
This README will guide you through the process of using the generated JavaScript SDK package for the connector `example`. It will also provide examples on how to use your generated SDK to call your Data Connect queries and mutations.

**If you're looking for the `React README`, you can find it at [`dataconnect-generated/react/README.md`](./react/README.md)**

***NOTE:** This README is generated alongside the generated SDK. If you make changes to this file, they will be overwritten when the SDK is regenerated.*

# Table of Contents
- [**Overview**](#generated-javascript-readme)
- [**Accessing the connector**](#accessing-the-connector)
  - [*Connecting to the local Emulator*](#connecting-to-the-local-emulator)
- [**Queries**](#queries)
  - [*ListAllTeams*](#listallteams)
  - [*ListMyTeams*](#listmyteams)
- [**Mutations**](#mutations)
  - [*CreateDemoUser*](#createdemouser)
  - [*UpdatePlayerJerseyNumber*](#updateplayerjerseynumber)

# Accessing the connector
A connector is a collection of Queries and Mutations. One SDK is generated for each connector - this SDK is generated for the connector `example`. You can find more information about connectors in the [Data Connect documentation](https://firebase.google.com/docs/data-connect#how-does).

You can use this generated SDK by importing from the package `@dataconnect/generated` as shown below. Both CommonJS and ESM imports are supported.

You can also follow the instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#set-client).

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
```

## Connecting to the local Emulator
By default, the connector will connect to the production service.

To connect to the emulator, you can use the following code.
You can also follow the emulator instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#instrument-clients).

```typescript
import { connectDataConnectEmulator, getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
connectDataConnectEmulator(dataConnect, 'localhost', 9399);
```

After it's initialized, you can call your Data Connect [queries](#queries) and [mutations](#mutations) from your generated SDK.

# Queries

There are two ways to execute a Data Connect Query using the generated Web SDK:
- Using a Query Reference function, which returns a `QueryRef`
  - The `QueryRef` can be used as an argument to `executeQuery()`, which will execute the Query and return a `QueryPromise`
- Using an action shortcut function, which returns a `QueryPromise`
  - Calling the action shortcut function will execute the Query and return a `QueryPromise`

The following is true for both the action shortcut function and the `QueryRef` function:
- The `QueryPromise` returned will resolve to the result of the Query once it has finished executing
- If the Query accepts arguments, both the action shortcut function and the `QueryRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Query
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `example` connector's generated functions to execute each query. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-queries).

## ListAllTeams
You can execute the `ListAllTeams` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listAllTeams(options?: ExecuteQueryOptions): QueryPromise<ListAllTeamsData, undefined>;

interface ListAllTeamsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListAllTeamsData, undefined>;
}
export const listAllTeamsRef: ListAllTeamsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listAllTeams(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListAllTeamsData, undefined>;

interface ListAllTeamsRef {
  ...
  (dc: DataConnect): QueryRef<ListAllTeamsData, undefined>;
}
export const listAllTeamsRef: ListAllTeamsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listAllTeamsRef:
```typescript
const name = listAllTeamsRef.operationName;
console.log(name);
```

### Variables
The `ListAllTeams` query has no variables.
### Return Type
Recall that executing the `ListAllTeams` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListAllTeamsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListAllTeamsData {
  teams: ({
    id: UUIDString;
    name: string;
    description?: string | null;
  } & Team_Key)[];
}
```
### Using `ListAllTeams`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listAllTeams } from '@dataconnect/generated';


// Call the `listAllTeams()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listAllTeams();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listAllTeams(dataConnect);

console.log(data.teams);

// Or, you can use the `Promise` API.
listAllTeams().then((response) => {
  const data = response.data;
  console.log(data.teams);
});
```

### Using `ListAllTeams`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listAllTeamsRef } from '@dataconnect/generated';


// Call the `listAllTeamsRef()` function to get a reference to the query.
const ref = listAllTeamsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listAllTeamsRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.teams);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.teams);
});
```

## ListMyTeams
You can execute the `ListMyTeams` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listMyTeams(options?: ExecuteQueryOptions): QueryPromise<ListMyTeamsData, undefined>;

interface ListMyTeamsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListMyTeamsData, undefined>;
}
export const listMyTeamsRef: ListMyTeamsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listMyTeams(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListMyTeamsData, undefined>;

interface ListMyTeamsRef {
  ...
  (dc: DataConnect): QueryRef<ListMyTeamsData, undefined>;
}
export const listMyTeamsRef: ListMyTeamsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listMyTeamsRef:
```typescript
const name = listMyTeamsRef.operationName;
console.log(name);
```

### Variables
The `ListMyTeams` query has no variables.
### Return Type
Recall that executing the `ListMyTeams` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListMyTeamsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListMyTeamsData {
  teams: ({
    id: UUIDString;
    name: string;
    description?: string | null;
  } & Team_Key)[];
}
```
### Using `ListMyTeams`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listMyTeams } from '@dataconnect/generated';


// Call the `listMyTeams()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listMyTeams();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listMyTeams(dataConnect);

console.log(data.teams);

// Or, you can use the `Promise` API.
listMyTeams().then((response) => {
  const data = response.data;
  console.log(data.teams);
});
```

### Using `ListMyTeams`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listMyTeamsRef } from '@dataconnect/generated';


// Call the `listMyTeamsRef()` function to get a reference to the query.
const ref = listMyTeamsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listMyTeamsRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.teams);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.teams);
});
```

# Mutations

There are two ways to execute a Data Connect Mutation using the generated Web SDK:
- Using a Mutation Reference function, which returns a `MutationRef`
  - The `MutationRef` can be used as an argument to `executeMutation()`, which will execute the Mutation and return a `MutationPromise`
- Using an action shortcut function, which returns a `MutationPromise`
  - Calling the action shortcut function will execute the Mutation and return a `MutationPromise`

The following is true for both the action shortcut function and the `MutationRef` function:
- The `MutationPromise` returned will resolve to the result of the Mutation once it has finished executing
- If the Mutation accepts arguments, both the action shortcut function and the `MutationRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Mutation
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `example` connector's generated functions to execute each mutation. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-mutations).

## CreateDemoUser
You can execute the `CreateDemoUser` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createDemoUser(): MutationPromise<CreateDemoUserData, undefined>;

interface CreateDemoUserRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): MutationRef<CreateDemoUserData, undefined>;
}
export const createDemoUserRef: CreateDemoUserRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createDemoUser(dc: DataConnect): MutationPromise<CreateDemoUserData, undefined>;

interface CreateDemoUserRef {
  ...
  (dc: DataConnect): MutationRef<CreateDemoUserData, undefined>;
}
export const createDemoUserRef: CreateDemoUserRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createDemoUserRef:
```typescript
const name = createDemoUserRef.operationName;
console.log(name);
```

### Variables
The `CreateDemoUser` mutation has no variables.
### Return Type
Recall that executing the `CreateDemoUser` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateDemoUserData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateDemoUserData {
  user_insert: User_Key;
}
```
### Using `CreateDemoUser`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createDemoUser } from '@dataconnect/generated';


// Call the `createDemoUser()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createDemoUser();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createDemoUser(dataConnect);

console.log(data.user_insert);

// Or, you can use the `Promise` API.
createDemoUser().then((response) => {
  const data = response.data;
  console.log(data.user_insert);
});
```

### Using `CreateDemoUser`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createDemoUserRef } from '@dataconnect/generated';


// Call the `createDemoUserRef()` function to get a reference to the mutation.
const ref = createDemoUserRef();

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createDemoUserRef(dataConnect);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.user_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.user_insert);
});
```

## UpdatePlayerJerseyNumber
You can execute the `UpdatePlayerJerseyNumber` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updatePlayerJerseyNumber(vars: UpdatePlayerJerseyNumberVariables): MutationPromise<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;

interface UpdatePlayerJerseyNumberRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdatePlayerJerseyNumberVariables): MutationRef<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;
}
export const updatePlayerJerseyNumberRef: UpdatePlayerJerseyNumberRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updatePlayerJerseyNumber(dc: DataConnect, vars: UpdatePlayerJerseyNumberVariables): MutationPromise<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;

interface UpdatePlayerJerseyNumberRef {
  ...
  (dc: DataConnect, vars: UpdatePlayerJerseyNumberVariables): MutationRef<UpdatePlayerJerseyNumberData, UpdatePlayerJerseyNumberVariables>;
}
export const updatePlayerJerseyNumberRef: UpdatePlayerJerseyNumberRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updatePlayerJerseyNumberRef:
```typescript
const name = updatePlayerJerseyNumberRef.operationName;
console.log(name);
```

### Variables
The `UpdatePlayerJerseyNumber` mutation requires an argument of type `UpdatePlayerJerseyNumberVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdatePlayerJerseyNumberVariables {
  id: UUIDString;
  jerseyNumber: number;
}
```
### Return Type
Recall that executing the `UpdatePlayerJerseyNumber` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdatePlayerJerseyNumberData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdatePlayerJerseyNumberData {
  player_update?: Player_Key | null;
}
```
### Using `UpdatePlayerJerseyNumber`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updatePlayerJerseyNumber, UpdatePlayerJerseyNumberVariables } from '@dataconnect/generated';

// The `UpdatePlayerJerseyNumber` mutation requires an argument of type `UpdatePlayerJerseyNumberVariables`:
const updatePlayerJerseyNumberVars: UpdatePlayerJerseyNumberVariables = {
  id: ..., 
  jerseyNumber: ..., 
};

// Call the `updatePlayerJerseyNumber()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updatePlayerJerseyNumber(updatePlayerJerseyNumberVars);
// Variables can be defined inline as well.
const { data } = await updatePlayerJerseyNumber({ id: ..., jerseyNumber: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updatePlayerJerseyNumber(dataConnect, updatePlayerJerseyNumberVars);

console.log(data.player_update);

// Or, you can use the `Promise` API.
updatePlayerJerseyNumber(updatePlayerJerseyNumberVars).then((response) => {
  const data = response.data;
  console.log(data.player_update);
});
```

### Using `UpdatePlayerJerseyNumber`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updatePlayerJerseyNumberRef, UpdatePlayerJerseyNumberVariables } from '@dataconnect/generated';

// The `UpdatePlayerJerseyNumber` mutation requires an argument of type `UpdatePlayerJerseyNumberVariables`:
const updatePlayerJerseyNumberVars: UpdatePlayerJerseyNumberVariables = {
  id: ..., 
  jerseyNumber: ..., 
};

// Call the `updatePlayerJerseyNumberRef()` function to get a reference to the mutation.
const ref = updatePlayerJerseyNumberRef(updatePlayerJerseyNumberVars);
// Variables can be defined inline as well.
const ref = updatePlayerJerseyNumberRef({ id: ..., jerseyNumber: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updatePlayerJerseyNumberRef(dataConnect, updatePlayerJerseyNumberVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.player_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.player_update);
});
```


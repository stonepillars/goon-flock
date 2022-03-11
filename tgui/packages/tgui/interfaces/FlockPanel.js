import { sortBy } from "../../common/collections";
import { useBackend, useLocalState, useSharedState } from "../backend";
import { Flex, Button, Stack, Tabs, Icon, Box, Section, Dropdown } from "../components";
import { FlexItem } from "../components/Flex";
import { Window } from '../layouts';

const FlockPartitions = (props, context) => {
  const { act } = useBackend(context);
  const {
    partitions,
  } = props;
  return (
    <Stack vertical>
      {partitions.map(partition => {
        return (
          <Stack.Item key={partition.ref}>
            <Section>
              <Stack>
                <Stack.Item>
                  <Stack vertical align="center">
                    <Stack.Item >{partition.name}</Stack.Item>
                    <Stack.Item >{partition.health}<Icon name="heart" /></Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item grow={1}>{partition.host}</Stack.Item>
                <Stack.Item>
                  <Button onClick={() => act('jump_to', { 'origin': partition.ref })} >
                    Jump
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
        );
      })}
    </Stack>
  );
};

const compare = function (a, b, sortBy) {
  if (!isNaN(a[sortBy]) && !isNaN(b[sortBy])) {
    return b[sortBy] - a[sortBy];
  }
  return ('' + a[sortBy]).localeCompare(b[sortBy]);
};

const iconLookup = {
  "thinking": "brain",
  "shooting": "bolt",
  "moving": "forward",
  "wandering": "question",
  "building": "hammer",
  "harvesting": "cogs",
};
const taskIcon = function (task) {
  let iconString = iconLookup[task];
  if (iconString) {
    return <Icon size={3} name={iconString} />;
  }
  return "";
};

const capitalizeString = function (string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
};

const FlockDrones = (props, context) => {
  const { act } = useBackend(context);
  const {
    drones,
    sortBy,
  } = props;
  return (
    <Stack vertical>
      {drones
        .sort(
          (a, b) => (compare(a, b, sortBy))
        ).map(drone => {
          return (
            <Stack.Item key={drone.ref}>
              <Stack>
                {/* name, health and resources */}
                <Stack.Item width="20%">
                  <Section height="100%">
                    <Stack vertical align="center">
                      <Stack.Item >{drone.name}</Stack.Item>
                      <Stack.Item >{drone.health}<Icon name="heart" /> {drone.resources}<Icon name="cog" /></Stack.Item>
                    </Stack>
                  </Section>
                </Stack.Item>
                {/* area and task */}
                <Stack.Item grow={1}>
                  <Section height="100%">
                    <Stack align="center">
                      <Stack.Item width="50px" align="center">
                        {taskIcon(drone.task)}
                      </Stack.Item>
                      <Stack.Item>
                        <b>{drone.area}</b> <br /> {capitalizeString(drone.task)}
                      </Stack.Item>
                    </Stack>
                  </Section>
                </Stack.Item>
                {/* jump, rally and eject buttons */}
                <Stack.Item>
                  <Section height="100%">
                    <Stack>
                      <Stack.Item>
                        <Button onClick={() => act('jump_to', { 'origin': drone.ref })} >
                          Jump
                        </Button>
                      </Stack.Item>
                      <Stack.Item>
                        <Button onClick={() => act('rally', { 'origin': drone.ref })} >
                          Rally
                        </Button>
                      </Stack.Item>
                      {drone.task === "controlled"
                          && (
                            <Stack.Item>
                              <Button onClick={() => act('eject_trace', { 'origin': drone.controller_ref })} >
                                Eject Trace
                              </Button>
                            </Stack.Item>
                          )}
                    </Stack>
                  </Section>
                </Stack.Item>

              </Stack>
            </Stack.Item>
          );
        })}
    </Stack>
  );
};

const FlockStructures = (props, context) => {
  const { act } = useBackend(context);
  const { structures } = props;
  return (
    <Stack vertical>
      {structures.map(structure => {
        return (
          <Stack.Item key={structure.ref}>
            <Stack>
              <Stack.Item grow={1}>
                <Section>
                  <Stack vertical align="center">
                    <Stack.Item >{structure.name}</Stack.Item>
                    <Stack.Item >{structure.health}<Icon name="heart" /></Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Section height="100%">
                  <Button onClick={() => act('jump_to', { 'origin': structure.ref })} >
                    Jump
                  </Button>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        );
      })}
    </Stack>
  );
};

export const FlockPanel = (props, context) => {
  const { data, act } = useBackend(context);
  const [tabIndex, setTabIndex] = useLocalState(context, 'tabIndex', 1);
  const [sortBy, setSortBy] = useLocalState(context, 'sortBy', 'resources');
  const {
    vitals,
    partitions,
    drones,
    structures,
    enemies,
  } = data;
  return (
    <Window
      theme="flock"
      title={"Flockmind " + vitals.name}
      width={600}
      height={450}
    >
      <Window.Content scrollable>
        <Tabs>
          <Tabs.Tab
            selected={tabIndex === 1}
            onClick={() => setTabIndex(1)}>
            Partitions {"(" + partitions.length + ")"}
          </Tabs.Tab>
          <Tabs.Tab
            selected={tabIndex === 2}
            onClick={() => setTabIndex(2)}>
            Drones {"(" + drones.length + ")"}
          </Tabs.Tab>
          <Tabs.Tab
            selected={tabIndex === 3}
            onClick={() => setTabIndex(3)}>
            Structures {"(" + structures.length + ")"}
          </Tabs.Tab>
        </Tabs>

        {tabIndex === 1 && <FlockPartitions partitions={partitions} />}
        {tabIndex === 2
        && (
          <Box>
            <Dropdown
              options={["name", "health", "resources", "area"]}
              selected="resources"
              onSelected={(value) => setSortBy(value)}
            />
            <FlockDrones drones={drones} sortBy={sortBy} />
          </Box>
        )}
        {tabIndex === 3 && <FlockStructures structures={structures} />}
      </Window.Content>
    </Window>
  );
};

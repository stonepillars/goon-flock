import { useBackend, useLocalState } from "../backend";
import { Flex, Tabs, Icon, Box, Section } from "../components";
import { FlexItem } from "../components/Flex";
import { Window } from '../layouts';

const FlockVitals = (props, context) => {
  const {
    name,
    drones,
    partitions,
  } = props;
  return (
    <Flex direction="column">
      <Flex.Item grow={1}>
        <Flex.Item strong>NAME: {name}</Flex.Item>
      </Flex.Item>
      <Flex.Item grow={1}>
        <Flex.Item strong>DRONES: {drones}</Flex.Item>
      </Flex.Item>
      <Flex.Item grow={1}>
        <Flex.Item strong>PARTITIONS: {partitions}</Flex.Item>
      </Flex.Item>
    </Flex>
  );
};

const FlockPartitions = (props, context) => {
  const {
    partitions,
  } = props;
  return (
    <Section>
      <Section>
        <Flex>
          <Flex.Item grow={1}>NAME</Flex.Item>
          <Flex.Item grow={1}>HOST</Flex.Item>
          <Flex.Item grow={1}><Icon name="heart" /></Flex.Item>
        </Flex>
      </Section>
      {partitions.map(partition => {
        return (
          <Flex direction="row" key={partition.ref}>
            <Flex.Item grow={1}>{partition.name}</Flex.Item>
            <Flex.Item grow={1}>{partition.host}</Flex.Item>
            <Flex.Item grow={1}>{partition.health}</Flex.Item>
          </Flex>
        );
      })}
    </Section>
  );
};

const FlockDrones = (props, context) => {
  const {
    drones,
  } = props;
  return (
    <Flex>
      <Flex.Item>
        <Flex.Item>NAME</Flex.Item>
        <Flex.Item><Icon name="heart" /></Flex.Item>
        <Flex.Item><Icon name="cog" /></Flex.Item>
        <Flex.Item>TASK</Flex.Item>
        <Flex.Item>AREA</Flex.Item>
      </Flex.Item>
    </Flex>
  );
};

export const FlockPanel = (props, context) => {
  const { data, act } = useBackend(context);
  const [tabIndex, setTabIndex] = useLocalState(context, 'tabIndex', 1);
  return (
    <Window
      // theme="flock-panel"
    >
      <Window.Content scrollable>
        <Tabs>
          <Tabs.Tab
            selected={tabIndex === 1}
            onClick={() => setTabIndex(1)}>
            Vitals
          </Tabs.Tab>
          <Tabs.Tab
            selected={tabIndex === 2}
            onClick={() => setTabIndex(2)}>
            Partitions
          </Tabs.Tab>
        </Tabs>
        {/* <Box>
          Tab selected: {tabIndex}
        </Box> */}
        {tabIndex === 1 && <FlockVitals name="flock thing" drones={42} partitions={3} />}
        {tabIndex === 2 && <FlockPartitions partitions={[{ ref: 3, name: "part1", host: "something", health: 72 }]} />}
      </Window.Content>
    </Window>
  );
};

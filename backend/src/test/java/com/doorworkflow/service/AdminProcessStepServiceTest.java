package com.doorworkflow.service;

import com.doorworkflow.dto.request.CreateProcessStepRequest;
import com.doorworkflow.dto.request.UpdateProcessStepRequest;
import com.doorworkflow.dto.response.ProcessStepResponse;
import com.doorworkflow.entity.ProcessStep;
import com.doorworkflow.repository.ProcessStepRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AdminProcessStepServiceTest {

    @Mock
    private ProcessStepRepository repository;

    @InjectMocks
    private AdminProcessStepService service;

    private final UUID id1 = UUID.randomUUID();
    private final UUID id2 = UUID.randomUUID();
    private final UUID id3 = UUID.randomUUID();

    private ProcessStep step1;
    private ProcessStep step2;
    private ProcessStep step3;

    @BeforeEach
    void setUp() {
        // common step fixtures (active by default)
        step1 = ProcessStep.builder()
                .id(id1)
                .name("Step One")
                .stepOrder(1)
                .isActive(true)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        step2 = ProcessStep.builder()
                .id(id2)
                .name("Step Two")
                .stepOrder(2)
                .isActive(true)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        step3 = ProcessStep.builder()
                .id(id3)
                .name("Step Three")
                .stepOrder(3)
                .isActive(true)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
    }

    @Test
    void createFirstActiveStep() {
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(new ArrayList<>());
        when(repository.save(any(ProcessStep.class))).thenAnswer(invocation -> {
            ProcessStep s = invocation.getArgument(0);
            s.setId(UUID.randomUUID());
            return s;
        });

        CreateProcessStepRequest req = new CreateProcessStepRequest("First", 1);
        ProcessStepResponse resp = service.createProcessStep(req);

        assertEquals("First", resp.name());
        assertEquals(1, resp.stepOrder());
        assertTrue(resp.isActive());
        verify(repository).saveAll(anyList()); // no shift but saveAll called with empty list is okay
        verify(repository).save(any(ProcessStep.class));
    }

    @Test
    void createStepAtExistingPositionShiftsFollowing() {
        List<ProcessStep> existing = List.of(step1, step2);
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(existing);
        when(repository.saveAll(anyList())).thenAnswer(i -> i.getArgument(0));
        when(repository.save(any(ProcessStep.class))).thenAnswer(i -> i.getArgument(0));

        CreateProcessStepRequest req = new CreateProcessStepRequest("New", 2);
        ProcessStepResponse resp = service.createProcessStep(req);

        // step2 should have been shifted to order 3
        ArgumentCaptor<List<ProcessStep>> captor = ArgumentCaptor.forClass(List.class);
        verify(repository).saveAll(captor.capture());
        List<ProcessStep> saved = captor.getValue();
        ProcessStep shifted = saved.stream().filter(s -> s.getId().equals(step2.getId())).findFirst().orElseThrow();
        assertEquals(3, shifted.getStepOrder());
        // new step order must be 2
        assertEquals(2, resp.stepOrder());
    }

    @Test
    void createRejectsOrderTooHigh() {
        List<ProcessStep> existing = List.of(step1);
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(existing);
        CreateProcessStepRequest req = new CreateProcessStepRequest("Bad", 3); // activeCount=1, allowed max=2
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.createProcessStep(req));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
    }

    @Test
    void createRejectsDuplicateActiveNameCaseInsensitive() {
        List<ProcessStep> existing = List.of(step1);
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(existing);
        CreateProcessStepRequest req = new CreateProcessStepRequest("step ONE", 2);
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.createProcessStep(req));
        assertEquals(HttpStatus.CONFLICT, ex.getStatusCode());
    }

    @Test
    void listIncludesInactiveSteps() {
        ProcessStep inactive = ProcessStep.builder()
                .id(UUID.randomUUID())
                .name("Inactive")
                .stepOrder(99)
                .isActive(false)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(List.of(step1, inactive));
        List<ProcessStepResponse> list = service.listProcessSteps();
        assertEquals(2, list.size());
        assertTrue(list.stream().anyMatch(r -> !r.isActive()));
    }

    @Test
    void getExistingStep() {
        when(repository.findById(id1)).thenReturn(Optional.of(step1));
        ProcessStepResponse resp = service.getProcessStep(id1);
        assertEquals(step1.getName(), resp.name());
        assertEquals(step1.getStepOrder(), resp.stepOrder());
    }

    @Test
    void getMissingStepThrowsNotFound() {
        when(repository.findById(any())).thenReturn(Optional.empty());
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.getProcessStep(UUID.randomUUID()));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }

    @Test
    void renameActiveStep() {
        when(repository.findById(id1)).thenReturn(Optional.of(step1));
        when(repository.save(any(ProcessStep.class))).thenAnswer(i -> i.getArgument(0));
        UpdateProcessStepRequest req = new UpdateProcessStepRequest("Renamed", 1);
        ProcessStepResponse resp = service.updateProcessStep(id1, req);
        assertEquals("Renamed", resp.name());
        verify(repository).save(step1);
    }

    @Test
    void reorderActiveStepUpwardShiftsOthers() {
        List<ProcessStep> existing = List.of(step1, step2, step3);
        when(repository.findById(id3)).thenReturn(Optional.of(step3));
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(existing);
        when(repository.saveAll(anyList())).thenAnswer(i -> i.getArgument(0));
        when(repository.save(any(ProcessStep.class))).thenAnswer(i -> i.getArgument(0));
        UpdateProcessStepRequest req = new UpdateProcessStepRequest("Step Three", 1);
        ProcessStepResponse resp = service.updateProcessStep(id3, req);
        assertEquals(1, resp.stepOrder());
        // capture shifted list
        ArgumentCaptor<List<ProcessStep>> captor = ArgumentCaptor.forClass(List.class);
        verify(repository).saveAll(captor.capture());
        List<ProcessStep> shifted = captor.getValue();
        assertEquals(2, shifted.stream().filter(s -> s.getId().equals(step1.getId())).findFirst().orElseThrow().getStepOrder());
        assertEquals(3, shifted.stream().filter(s -> s.getId().equals(step2.getId())).findFirst().orElseThrow().getStepOrder());
    }

    @Test
    void reorderActiveStepDownwardShiftsOthers() {
        List<ProcessStep> existing = List.of(step1, step2, step3);
        when(repository.findById(id1)).thenReturn(Optional.of(step1));
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(existing);
        when(repository.saveAll(anyList())).thenAnswer(i -> i.getArgument(0));
        when(repository.save(any(ProcessStep.class))).thenAnswer(i -> i.getArgument(0));
        UpdateProcessStepRequest req = new UpdateProcessStepRequest("Step One", 3);
        ProcessStepResponse resp = service.updateProcessStep(id1, req);
        assertEquals(3, resp.stepOrder());
        ArgumentCaptor<List<ProcessStep>> captor = ArgumentCaptor.forClass(List.class);
        verify(repository).saveAll(captor.capture());
        List<ProcessStep> shifted = captor.getValue();
        // step2 should become 1, step3 becomes 2
        assertEquals(1, shifted.stream().filter(s -> s.getId().equals(step2.getId())).findFirst().orElseThrow().getStepOrder());
        assertEquals(2, shifted.stream().filter(s -> s.getId().equals(step3.getId())).findFirst().orElseThrow().getStepOrder());
    }

    @Test
    void deactivateActiveStepClosesGap() {
        List<ProcessStep> existing = List.of(step1, step2, step3);
        when(repository.findById(id2)).thenReturn(Optional.of(step2));
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(existing);
        when(repository.save(any(ProcessStep.class))).thenAnswer(i -> i.getArgument(0));
        when(repository.saveAll(anyList())).thenAnswer(i -> i.getArgument(0));
        ProcessStepResponse resp = service.deactivateProcessStep(id2);
        assertFalse(resp.isActive());
        // after deactivation, step3 should shift from 3 to 2
        ArgumentCaptor<List<ProcessStep>> captor = ArgumentCaptor.forClass(List.class);
        verify(repository).saveAll(captor.capture());
        List<ProcessStep> shifted = captor.getValue();
        assertEquals(2, shifted.stream().filter(s -> s.getId().equals(step3.getId())).findFirst().orElseThrow().getStepOrder());
    }

    @Test
    void deactivateAlreadyInactiveIsIdempotent() {
        ProcessStep inactive = ProcessStep.builder()
                .id(UUID.randomUUID())
                .name("Inactive")
                .stepOrder(5)
                .isActive(false)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        when(repository.findById(inactive.getId())).thenReturn(Optional.of(inactive));
        ProcessStepResponse resp = service.deactivateProcessStep(inactive.getId());
        assertFalse(resp.isActive());
        verify(repository, never()).saveAll(any());
        verify(repository, never()).save(any());
    }

    @Test
    void updateInactiveStepDoesNotAffectActiveOrdering() {
        ProcessStep inactive = ProcessStep.builder()
                .id(UUID.randomUUID())
                .name("Old")
                .stepOrder(5)
                .isActive(false)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        List<ProcessStep> active = List.of(step1, step2, step3);
        when(repository.findById(inactive.getId())).thenReturn(Optional.of(inactive));
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(active);
        when(repository.save(any(ProcessStep.class))).thenAnswer(i -> i.getArgument(0));
        UpdateProcessStepRequest req = new UpdateProcessStepRequest("NewName", 6);
        ProcessStepResponse resp = service.updateProcessStep(inactive.getId(), req);
        assertEquals(6, resp.stepOrder());
        assertEquals("NewName", resp.name());
        // No reordering of active steps should happen
        verify(repository, never()).saveAll(any());
    }

    @Test
    void reactivateStepSuccessfullyAppendsToEnd() {
        ProcessStep inactive = ProcessStep.builder()
                .id(UUID.randomUUID())
                .name("Inactive Step")
                .stepOrder(2)
                .isActive(false)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        List<ProcessStep> active = List.of(step1, step2, step3);
        when(repository.findById(inactive.getId())).thenReturn(Optional.of(inactive));
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(active);
        when(repository.save(any(ProcessStep.class))).thenAnswer(i -> i.getArgument(0));

        ProcessStepResponse resp = service.reactivateProcessStep(inactive.getId());

        assertTrue(resp.isActive());
        assertEquals(4, resp.stepOrder());
        assertEquals("Inactive Step", resp.name());
        verify(repository).save(inactive);
    }

    @Test
    void reactivateAlreadyActiveThrowsBadRequest() {
        when(repository.findById(id1)).thenReturn(Optional.of(step1));
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.reactivateProcessStep(id1));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
        assertEquals("Process step is already active", ex.getReason());
    }

    @Test
    void reactivateDuplicateActiveNameThrowsConflict() {
        ProcessStep inactive = ProcessStep.builder()
                .id(UUID.randomUUID())
                .name("step ONE")
                .stepOrder(2)
                .isActive(false)
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        List<ProcessStep> active = List.of(step1, step2);
        when(repository.findById(inactive.getId())).thenReturn(Optional.of(inactive));
        when(repository.findAllByOrderByStepOrderAsc()).thenReturn(active);

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.reactivateProcessStep(inactive.getId()));
        assertEquals(HttpStatus.CONFLICT, ex.getStatusCode());
        assertEquals("Active process step name already exists", ex.getReason());
    }

    @Test
    void reactivateMissingStepThrowsNotFound() {
        UUID randomId = UUID.randomUUID();
        when(repository.findById(randomId)).thenReturn(Optional.empty());
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.reactivateProcessStep(randomId));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
    }
}
